local _, NS = ...
-- modules/Outfits.lua — NS.Outfits: the outfit store (design §5.6).
--
-- THE ONE WRITER of db.char.outfits, order, bindings, nextID and seeded outside the instance-row path
-- (C12; the instance rows write through modules/Outfits_Schema.lua, whose announce comes back here
-- through O.Changed). The only sender of OUTFIT_ADDED, OUTFIT_DELETED, OUTFIT_EDITED and
-- OUTFIT_RENAMED. modules/Outfits_Seed.lua extends this table with LoadPass and the lifecycle.
--
-- IDS (C9). An outfit is "o<N>": N comes from char.nextID, which only ever moves up, so an id is
-- never reused. O.Get answers nil for anything else, which is what keeps a test-mode "preview:<n>"
-- placeholder from ever reaching the Stack or Equip (C28). A stale id in the stack, the recents or
-- the bindings reads as "none".
--
-- KINDS. A record is "native" (its items are rec.items) or "em", a mirror of a Blizzard equipment
-- set whose items the EM module resolves. The KIND table below is the one dispatch, replacing the
-- legacy pair of method metatables.
--
-- CALLS (at call time, no nil guard; design §12): NS.Stack.Remove/Select/Clear/Wear, NS.TriggerBinder
-- .Unbind/UnbindAll, NS.EM.Items/SetItem/ClearSlot/Rename/DeleteSet, NS.Inventory.Cache/Missing/
-- OutfitsUsing, and NS.PlayerState.InCombat.

local O = {}
NS.Outfits = O

local L = NS.L
local ID = NS.ItemData

local CATEGORIES = { "Complete", "Accessory" }
local MAX_BINDING = 10
local TWO_HANDER = "INVTYPE_2HWEAPON"
-- The record flags O.SetFlag writes. The icon, bar.hide and the trigger flags are instance rows
-- (design §3.5), so they are not here.
local FLAGS = { unequipOthers = "bool", ignoreComparisons = "bool", titleID = "number" }

local function store() return NS.db.char end

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

local function emptyMarker() return { id = 0 } end

-- ── reads ─────────────────────────────────────────────────────────────────────────────────────

--- The record for `id`, or nil: nil for an unknown id and for anything that is not "o<N>" (C28).
--- @param id any
--- @return table|nil
function O.Get(id)
    if type(id) ~= "string" or not id:find("^o%d+$") then return nil end
    local db = NS.db
    local outfits = db and db.char and db.char.outfits
    return outfits and outfits[id] or nil
end

--- The two categories, in display order.
--- @return string[]
function O.Categories()
    return { CATEGORIES[1], CATEGORIES[2] }
end

--- The ids of one category, in display order, skipping stale ones (a copy; never the store's).
--- @param category string
--- @return string[]
function O.Ids(category)
    local out = {}
    for _, id in ipairs(store().order[category] or {}) do
        if O.Get(id) then out[#out + 1] = id end
    end
    return out
end

--- Iterate one category: `for id, rec in O.Each("Complete") do`.
--- @param category string
function O.Each(category)
    local ids, i = O.Ids(category), 0
    return function()
        i = i + 1
        local id = ids[i]
        if id then return id, O.Get(id) end
    end
end

--- The id of the outfit named `name`, compared case-insensitively and exactly, or nil.
--- @param name string
--- @return string|nil
function O.FindByName(name)
    if type(name) ~= "string" then return nil end
    local want = name:lower()
    for id, rec in pairs(store().outfits) do
        if type(rec.name) == "string" and rec.name:lower() == want and O.Get(id) then return id end
    end
    return nil
end

--- @param id string
--- @return boolean
function O.IsEM(id)
    local rec = O.Get(id)
    return rec ~= nil and rec.kind == "em"
end

-- ── the kind dispatch ─────────────────────────────────────────────────────────────────────────

local KIND = {
    native = {
        Items     = function(rec) return rec.items end,
        SetItem   = function(rec, slot, item) rec.items[slot] = copy(item) end,
        ClearSlot = function(rec, slot) rec.items[slot] = nil end,
    },
    -- The EM variants unignore the slot and save; the set's resolved items are the EM's own.
    em = {
        Items     = function(rec) return NS.EM.Items(rec) end,
        SetItem   = function(rec, slot, item) NS.EM.SetItem(rec, slot, item) end,
        ClearSlot = function(rec, slot) NS.EM.ClearSlot(rec, slot) end,
    },
}

local function kindOf(rec) return KIND[rec.kind] or KIND.native end

--- An outfit's items, slot -> ItemRecord: the record's own (native) or the set's (em).
--- @param rec table
--- @return table
function O.Items(rec)
    return kindOf(rec).Items(rec) or {}
end

-- ── categories (B10) ──────────────────────────────────────────────────────────────────────────

--- THE one completeness rule, for both kinds (B10): every slot but UNEQUIP_EXEMPT is used, and the
--- off-hand may be unused under a two-handed main hand. An empty marker counts as used.
--- @param slotHas fun(slot: string): boolean
--- @param mainHandInvType string|nil
--- @return boolean
function O.IsComplete(slotHas, mainHandInvType)
    for _, slot in ipairs(ID.SLOT_NAMES) do
        if not ID.UNEQUIP_EXEMPT[slot] and not slotHas(slot) then
            if slot ~= "SecondaryHandSlot" or mainHandInvType ~= TWO_HANDER then return false end
        end
    end
    return true
end

--- "Complete" or "Accessory" for a record, from its items.
--- @param rec table
--- @return string
function O.Categorize(rec)
    local items = O.Items(rec)
    local mh = items.MainHandSlot
    local complete = O.IsComplete(function(slot) return items[slot] ~= nil end, mh and mh.invType)
    return complete and "Complete" or "Accessory"
end

local function unlinkOrder(id)
    for _, cat in ipairs(CATEGORIES) do
        local list = store().order[cat]
        for i = #list, 1, -1 do
            if list[i] == id then table.remove(list, i) end
        end
    end
end

--- Put the record in the order its category says, appended when it moves (Outfitter.lua:5069).
local function place(rec)
    local cat = O.Categorize(rec)
    local list = store().order[cat]
    local present = false
    for _, id in ipairs(list) do if id == rec.id then present = true end end
    if rec.category ~= cat or not present then
        unlinkOrder(rec.id)
        list[#list + 1] = rec.id
    end
    rec.category = cat
end
O.__place = place   -- modules/Outfits_Seed.lua's repair re-places every record through the same rule

--- The one edit tail: re-categorize, move between the orders, announce OUTFIT_EDITED (id, what).
--- @param id string
--- @param what string|nil  what changed: "items", "icon", "bar", "trigger", "binding", a flag name
function O.Changed(id, what)
    local rec = O.Get(id)
    if not rec then return end
    place(rec)
    NS.SendBus(NS.MSG.OUTFIT_EDITED, id, what)
end

-- ── create, duplicate, reorder ────────────────────────────────────────────────────────────────

local function triggerOf(t)
    if type(t) == "string" then return { id = t } end
    if type(t) == "table" then return copy(t) end
    return nil
end

-- A new record under the next id, not yet stored, placed or announced.
local function newRecord(name, items, opts)
    local c = store()
    local id = "o" .. c.nextID
    c.nextID = c.nextID + 1
    return { id = id, name = name, kind = opts.kind or "native", items = copy(items) or {},
             setID = opts.setID, icon = opts.icon, trigger = triggerOf(opts.trigger),
             builtin = opts.builtin, bar = {} }
end

-- Store, place and announce a whole record: OUTFIT_ADDED is the binder's Bind(id), so every field
-- it reads (the trigger, its params) must already be on the record.
local function add(rec)
    store().outfits[rec.id] = rec
    place(rec)
    NS.SendBus(NS.MSG.OUTFIT_ADDED, rec.id)
    return rec.id
end

--- A new outfit. `opts = { icon?, trigger? (an id or a trigger table), builtin?, kind?, setID? }`.
--- Allocates "o"..nextID, categorizes, appends to the order and sends OUTFIT_ADDED (the binder binds
--- a triggered outfit off that message).
--- @param name string
--- @param items table|nil  slot -> ItemRecord, copied in
--- @param opts table|nil
--- @return string id
function O.Create(name, items, opts)
    return add(newRecord(name, items, opts or {}))
end

--- The bar's item drop: an outfit named after the item, holding it in its slot. Nil for no item.
--- @param link string
--- @return string|nil id
function O.CreateFromItem(link)
    local info = NS.ItemInfo.FromLink(link)
    local slot = info and info.invType and ID.INVTYPE_TO_SLOT[info.invType]
    if not slot then return nil end
    return O.Create(info.name or "", { [slot.slot] = NS.ItemInfo.Snapshot(info) })
end

--- A free name for a copy of `name`: "<name> 2", "<name> 3", ...
local function freeName(name)
    local n = 2
    while O.FindByName(name .. " " .. n) do n = n + 1 end
    return name .. " " .. n
end

-- What a duplicate keeps of the record: every field but the identity, the seed key and the
-- trigger's persisted side-effect state (triggerState: CVar restores for a trigger the copy never ran).
local DUPLICATE_SKIP = { id = true, name = true, builtin = true, category = true, kind = true, setID = true,
                         items = true, triggerState = true }

--- A native copy of an outfit (an EM outfit's copy holds its resolved items), under a free name. The
--- copy is whole before OUTFIT_ADDED, so a copied trigger is bound at once (design §6.9).
--- @param id string
--- @return string|nil newId
function O.Duplicate(id)
    local rec = O.Get(id)
    if not rec then return nil end
    local dup = newRecord(freeName(rec.name or ""), O.Items(rec), {})
    for k, v in pairs(rec) do
        if not DUPLICATE_SKIP[k] then dup[k] = copy(v) end
    end
    return add(dup)
end

--- Replace a category's display order. Refused unless `ids` is exactly the same set of ids.
--- @param category string
--- @param ids string[]
--- @return boolean
function O.Reorder(category, ids)
    local current = O.Ids(category)
    if type(ids) ~= "table" or #ids ~= #current then return false end
    local want = {}
    for _, id in ipairs(current) do want[id] = true end
    for _, id in ipairs(ids) do
        if not want[id] then return false end
        want[id] = nil
    end
    local list = {}
    for i, id in ipairs(ids) do list[i] = id end
    store().order[category] = list
    return true
end

-- ── rename and delete ─────────────────────────────────────────────────────────────────────────

--- Rename an outfit. Refuses an empty name and another outfit's name (case-insensitively). An EM
--- outfit renames its set first, and that refusal stops the rename. No unwear/wear dance (O16).
--- @param id string
--- @param name string
--- @return boolean ok, string|nil errKey
function O.Rename(id, name)
    local rec = O.Get(id)
    if not rec or type(name) ~= "string" or name == "" then return false, L["That name is already used"] end
    local other = O.FindByName(name)
    if other and other ~= id then return false, L["That name is already used"] end
    if rec.kind == "em" then
        local ok, err = NS.EM.Rename(rec, name)
        if not ok then return false, err end
    end
    local old = rec.name
    rec.name = name
    NS.SendBus(NS.MSG.OUTFIT_RENAMED, id, old, name)
    return true
end

local function unbindKeys(id)
    local b = store().bindings
    for n = 1, MAX_BINDING do
        if b[n] == id then b[n] = nil end
    end
end

--- Delete one outfit: unwear, drop the selection, unbind its trigger, unlink it from the order and the key bindings,
--- delete its Blizzard set (em), then OUTFIT_DELETED (id, name).
--- @param id string
--- @return boolean
function O.Delete(id)
    local rec = O.Get(id)
    if not rec then return false end
    NS.Stack.Remove(id)
    -- After the remove: its fallback walk can re-wear (and with the window open re-select) this
    -- very outfit. The legacy DeleteOutfit cleared the selection too (Outfitter.lua:5101-5105).
    if NS.Stack.Selected() == id then NS.Stack.Select(nil) end
    NS.TriggerBinder.Unbind(id)
    unlinkOrder(id)
    unbindKeys(id)
    if rec.kind == "em" then NS.EM.DeleteSet(rec) end
    store().outfits[id] = nil
    NS.SendBus(NS.MSG.OUTFIT_DELETED, id, rec.name)
    return true
end

local function wipe(t) for k in pairs(t) do t[k] = nil end end

--- Delete every outfit on this character and re-seed the built-in ones (design §3.6). Refused in
--- combat and while stood down. The profile and the Blizzard sets are untouched; ids are not reused.
--- @return boolean ok, string|nil why
function O.DeleteAll()
    local refusal = NS.StoodDownRefusal()
    if refusal then return false, refusal end
    if NS.PlayerState.InCombat() then return false, L["Outfits can't be deleted in combat."] end
    NS.Stack.Select(nil)
    NS.TriggerBinder.UnbindAll()
    NS.Stack.Clear()
    local c = store()
    local gone = {}
    for id, rec in pairs(c.outfits) do gone[#gone + 1] = { id = id, name = rec.name } end
    table.sort(gone, function(a, b) return a.id < b.id end)
    wipe(c.outfits); wipe(c.bindings); wipe(c.stack); wipe(c.recent)
    c.order = { Complete = {}, Accessory = {} }
    c.emPreserved = nil
    c.seeded = false
    O.LoadPass()
    for _, g in ipairs(gone) do NS.SendBus(NS.MSG.OUTFIT_DELETED, g.id, g.name) end
    NS.Print(L["All outfits deleted. The built-in outfits were re-created."])
    return true
end

-- ── items and slots ───────────────────────────────────────────────────────────────────────────

--- The worn item in `slot` as a storable record, or the empty marker for an empty slot.
local function wornRecord(slot)
    local info = NS.ItemInfo.FromSlot(slot)
    if info then return NS.ItemInfo.Snapshot(info) end
    return emptyMarker()
end

--- Store `item` in one slot (kind dispatch), then Changed.
function O.SetItem(id, slot, item)
    local rec = O.Get(id)
    if not rec then return false end
    kindOf(rec).SetItem(rec, slot, item)
    O.Changed(id, "items")
    return true
end

--- Stop using one slot (kind dispatch), then Changed.
function O.ClearSlot(id, slot)
    local rec = O.Get(id)
    if not rec then return false end
    kindOf(rec).ClearSlot(rec, slot)
    O.Changed(id, "items")
    return true
end

local function setSlot(rec, slot, on)
    if on then
        kindOf(rec).SetItem(rec, slot, wornRecord(slot))
    else
        kindOf(rec).ClearSlot(rec, slot)
    end
end

--- The slot checkbox: enabling records the item worn there now (or the empty marker).
--- @param id string
--- @param slot string
--- @param on boolean
function O.SetSlotEnabled(id, slot, on)
    local rec = O.Get(id)
    if not rec then return false end
    setSlot(rec, slot, on)
    O.Changed(id, "items")
    return true
end

--- The footer's All / None (Outfitter.lua:5058): every slot at once, one Changed.
function O.SetAllSlotsEnabled(id, on)
    local rec = O.Get(id)
    if not rec then return false end
    for _, slot in ipairs(ID.SLOT_NAMES) do setSlot(rec, slot, on) end
    O.Changed(id, "items")
    return true
end

--- The checkbox tri-state: "off" (unused), "on" (used and worn), "unknown" (used, not worn).
--- @param id string
--- @param slot string
--- @param cache table  the inventory cache (NS.Inventory.Cache())
--- @return string
function O.SlotState(id, slot, cache)
    local rec = O.Get(id)
    local item = rec and O.Items(rec)[slot]
    if item == nil then return "off" end
    if cache:SlotHas(slot, item) then return "on" end
    return "unknown"
end

--- The slots in state "unknown", as a set.
function O.UnknownSlots(id, cache)
    local out = {}
    for _, slot in ipairs(ID.SLOT_NAMES) do
        if O.SlotState(id, slot, cache) == "unknown" then out[slot] = true end
    end
    return out
end

--- Window-open recording (Outfitter.lua:1938-1983, OutfitterOutfits.lua:46): the new items go into
--- the outfit, except over a slot in the "unknown" state. The model reads no frame. The Watch passes
--- the unknown set as it stood BEFORE the swap (modules/OutfitStack_Watch.lua): read after it, every
--- slot the outfit uses that the player just changed would read "unknown" and nothing would record.
--- @param id string
--- @param items table  slot -> ItemRecord
--- @param unknown table|nil  slot -> true; default: the slots unknown now (O.UnknownSlots)
function O.AddNewItems(id, items, unknown)
    local rec = O.Get(id)
    if not rec then return end
    unknown = unknown or O.UnknownSlots(id, NS.Inventory.Cache())
    for slot, item in pairs(items) do
        if not unknown[slot] then kindOf(rec).SetItem(rec, slot, item) end
    end
    O.Changed(id, "items")
end

--- Snapshot the worn items into every slot the outfit uses, wear it now, and say so. A nil id is
--- the "no Complete outfit" case (INV §5 Fix).
--- @param id string|nil
--- @return boolean ok, string msg
function O.SetToCurrent(id)
    local rec = O.Get(id)
    if not rec then return false, L["No Complete outfit is equipped."] end
    local slots = {}
    for slot in pairs(O.Items(rec)) do slots[#slots + 1] = slot end
    for _, slot in ipairs(slots) do setSlot(rec, slot, true) end
    O.Changed(id, "items")
    NS.Stack.Wear(id, { now = true })
    local msg = L["Updated the outfit '%s' to currently equipped items"]:format(tostring(rec.name))
    NS.Print(msg)
    return true, msg
end

--- For the row, the tooltip and the bar: "disabled" (the trigger's one Disabled flag), "missing",
--- "banked" or "normal".
--- @param id string
--- @param cache table|nil
--- @return string|nil
function O.Status(id, cache)
    local rec = O.Get(id)
    if not rec then return nil end
    if rec.trigger and rec.trigger.disabled then return "disabled" end
    local missing, banked = NS.Inventory.Missing(rec, cache)
    if missing and #missing > 0 then return "missing" end
    if banked and #banked > 0 then return "banked" end
    return "normal"
end

--- The outfits that use an item (the tooltips' "Used by", API v1 GetOutfitsUsingItem). The link is
--- read into an item info first: OutfitsUsing matches an info, and a secret or unparsable link reads
--- as no item, so as no outfit.
--- @param link any
--- @return string[]
function O.UsingItem(link)
    return NS.Inventory.OutfitsUsing(NS.ItemInfo.FromLink(link))
end

-- ── flags and bindings ────────────────────────────────────────────────────────────────────────

local function flagValue(kind, value)
    if kind == "bool" then return value and true or nil end
    if type(value) == "number" and value > 0 then return value end
    return nil
end

--- One of the allow-listed record flags; a cleared flag is stored as absent.
--- @return boolean
function O.SetFlag(id, key, value)
    local rec, kind = O.Get(id), FLAGS[key]
    if not rec or not kind then return false end
    rec[key] = flagValue(kind, value)
    O.Changed(id, key)
    return true
end

--- The binding key (1-10) the outfit holds, or nil.
function O.BindingOf(id)
    local b = store().bindings
    for n = 1, MAX_BINDING do
        if b[n] == id then return n end
    end
    return nil
end

--- The outfit bound to key `n`, or nil (a stale binding is none).
function O.BoundTo(n)
    local id = store().bindings[n]
    if O.Get(id) then return id end
    return nil
end

local function validKey(n)
    return type(n) == "number" and n >= 1 and n <= MAX_BINDING and n == math.floor(n)
end

--- Bind the outfit to key `n` (nil clears it). Unique by construction: `n` leaves whichever outfit
--- held it (Outfitter.lua:3704-3716).
--- @return boolean
function O.SetBinding(id, n)
    if not O.Get(id) or (n ~= nil and not validKey(n)) then return false end
    local b = store().bindings
    local previous = n and O.BoundTo(n)
    unbindKeys(id)
    if n then b[n] = id end
    if previous and previous ~= id then O.Changed(previous, "binding") end
    O.Changed(id, "binding")
    return true
end
