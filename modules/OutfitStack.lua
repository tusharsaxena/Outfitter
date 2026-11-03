local _, NS = ...
-- modules/OutfitStack.lua — NS.Stack: wear, remove, toggle, layers, recents, selection and title
-- (design §5.8; OutfitterEquipment.lua:986-1315 and Outfitter.lua:3404-3567 at 7ea3dc3).
--
-- THE ONE WRITER of db.char.stack and db.char.recent (design §3.4), named non-setting state. The
-- stack is ONE array of entries, bottom to top: `{ id, layer }` for an outfit, `{ temp, layer = nil }`
-- for a temporary outfit (slot -> ItemRecord). The legacy pair (LastOutfitStack beside a LayerIndex
-- map) drifted apart whenever the temps collapsed (B6); here a layer's insert point is DERIVED from
-- the entries' tags on every wear and never stored, so there is nothing to drift. The recents are
-- Complete-outfit ids, most recent LAST.
--
-- SESSION STATE: the selection, the expected outfit (what the last update compiled, plus what the
-- Watch has seen worn since), the key-binding anti-panic clock, and `rt[id] = { didEquip, didUnequip }`
-- (C31), which the smart-unequip reads.
--
-- A STALE ID (an outfit deleted while worn) reads as none: Compile, Top, CurrentInfo and
-- CurrentComplete skip it, and the next LoadPass repair (Init) drops it.
--
-- modules/OutfitStack_Watch.lua extends this table with the inventory watch (the temporary outfit,
-- window-open recording and SWAP_COMPLETE).
--
-- CALLS (at call time, no nil guard; design §12): NS.Equip.Batch/BatchNow/Request, NS.Outfits,
-- NS.Inventory.Cache, NS.ItemInfo, NS.Dock.IsShown and NS.SetByPath.

local St = {}
NS.Stack = St

local Compat = NS.Compat
local L = NS.L
local ID = NS.ItemData

local COMPLETE = "Complete"
local BINDING_REPEAT = 0.75   -- cMinBindingTime (Outfitter.lua:3721)

local selectedId           -- the window's selection (session)
local expected = {}        -- slot -> ItemRecord: what the stack should have put on
local rt = {}              -- [id] = { didEquip, didUnequip }
local lastBinding = {}     -- { n, at }: the anti-panic clock

local function store() return NS.db.char end
local function stack() return store().stack end
local function getRec(id) return NS.Outfits.Get(id) end

local function isComplete(rec) return rec ~= nil and rec.category == COMPLETE end

local function runtime(id)
    local r = rt[id]
    if not r then
        r = {}
        rt[id] = r
    end
    return r
end

local function indexOf(id)
    local s = stack()
    for i = 1, #s do
        if s[i].id == id then return i end
    end
    return nil
end

-- An entry's items, or nil for a stale id.
local function entryItems(entry)
    if entry.temp then return entry.temp end
    local rec = getRec(entry.id)
    return rec and NS.Outfits.Items(rec) or nil
end

-- The topmost entry that still resolves, and its index.
local function topLive()
    local s = stack()
    for i = #s, 1, -1 do
        if s[i].temp or getRec(s[i].id) then return s[i], i end
    end
    return nil
end

-- ── the temps (OutfitterEquipment.lua:1215-1250) ──────────────────────────────────────────────

-- Merge each run of adjacent temps upward: the lower's slots fill what the upper lacks, then it goes.
local function collapseTemps()
    local s = stack()
    local i = 2
    while i <= #s do
        local lower, upper = s[i - 1], s[i]
        if lower.temp and upper.temp then
            for slot, item in pairs(lower.temp) do
                if upper.temp[slot] == nil then upper.temp[slot] = item end
            end
            table.remove(s, i - 1)
        else
            i = i + 1
        end
    end
end
St.__collapseTemps = collapseTemps   -- the Watch's updateTemp removes a temp through the same rule

local function announceRemoved(entry, byTrigger)
    if entry.id then NS.SendBus(NS.MSG.OUTFIT_REMOVED, entry.id, byTrigger) end
end

-- Drop every entry `pred` holds for, announcing each, then collapse what that parted.
local function removeWhere(pred)
    local s = stack()
    for i = #s, 1, -1 do
        if pred(s[i]) then
            local entry = table.remove(s, i)
            announceRemoved(entry)
        end
    end
    collapseTemps()
end

-- ── layers (B6) ───────────────────────────────────────────────────────────────────────────────

-- The lowest entry tagged `layer`, else the top. Derived on every wear, never stored (B6, O39).
local function insertIndexFor(layer)
    local s = stack()
    if layer ~= nil then
        for i = 1, #s do
            if s[i].layer == layer then return i end
        end
    end
    return #s + 1
end

-- Put the outfit at its layer's point. False when it is already the topmost entry (the legacy
-- AddOutfit ignores that request). An existing entry is removed first, then the temps it parted
-- collapse.
local function pushEntry(id, layer)
    local s = stack()
    local at = indexOf(id)
    if at and at == #s then return false end
    if at then
        announceRemoved(table.remove(s, at))
        collapseTemps()
    end
    table.insert(s, insertIndexFor(layer), { id = id, layer = layer })
    return true
end

--- Tag an entry with a layer (Outfitter.lua:1277): the next wear of that layer goes under it.
--- @param id string
--- @param layer string
function St.TagLayer(id, layer)
    local at = indexOf(id)
    if at then stack()[at].layer = layer end
end

-- ── the recents ───────────────────────────────────────────────────────────────────────────────

local function unlinkRecent(id)
    local r = store().recent
    for i = #r, 1, -1 do
        if r[i] == id then table.remove(r, i) end
    end
end

-- Removing a Complete outfit wears the newest recent Complete outfit that still exists, pruning the
-- stale ones on the way (Outfitter.lua:3519-3545). Bounded by the list's length.
local function wearFallbackComplete()
    local r = store().recent
    for _ = 1, #r do
        local id = r[#r]
        if id == nil then return end
        if isComplete(getRec(id)) then
            St.Wear(id)
            return
        end
        table.remove(r)
    end
end

-- ── the selection ─────────────────────────────────────────────────────────────────────────────

--- Select an outfit (nil clears). Sends SELECTION_CHANGED when the selection moves.
--- @param id string|nil
function St.Select(id)
    local want = getRec(id) and id or nil
    if want == selectedId then return end
    selectedId = want
    NS.SendBus(NS.MSG.SELECTION_CHANGED, want)
end

--- @return string|nil
function St.Selected() return selectedId end

-- ── the title ─────────────────────────────────────────────────────────────────────────────────

--- The highest stacked outfit's title, set only inside a hardware event (INV §3.2, §13): a trigger
--- wear carries no `hw`, so it never changes the title.
--- @param hw boolean|nil
function St.UpdateTitle(hw)
    if not hw then return end
    local title
    for _, entry in ipairs(stack()) do
        local rec = entry.id and getRec(entry.id)
        if rec and rec.titleID ~= nil then title = rec.titleID end
    end
    if title ~= nil then Compat.SetCurrentTitle(title) end
end

-- ── wear ──────────────────────────────────────────────────────────────────────────────────────

-- The window's rule (Outfitter.lua:3446-3456): "If Outfitter is open then also select the outfit.
-- This is important because the UI can't function correctly if the selected outfit and top outfit
-- don't stay the same."
local function followSelection(id)
    if not NS.Dock.IsShown() then return end
    local top = topLive()
    if top and top.id == id then St.Select(id) else St.Select(nil) end
end

-- An Accessory outfit's entry (ClearCategory("Accessory")): never a temp, never a stale id.
local function isAccessory(entry)
    local rec = entry.id and getRec(entry.id)
    return rec ~= nil and rec.category == "Accessory"
end

local function pushRecent(id)
    unlinkRecent(id)
    local r = store().recent
    r[#r + 1] = id
end

local function wearBody(id, opts)
    local rec = getRec(id)
    if opts.clearDisabled and rec.trigger and rec.trigger.disabled then
        NS.SetByPath("outfit.trigger.disabled", false, id)
    end
    local complete = isComplete(rec)
    if complete then
        St.Clear()
    elseif rec.unequipOthers then
        removeWhere(isAccessory)
    end
    local pushed = pushEntry(id, opts.layer)
    if complete then pushRecent(id) end
    followSelection(id)
    local r = runtime(id)
    r.didEquip, r.didUnequip = opts.byTrigger and true or false, false
    NS.Equip.Request()
    if pushed then NS.SendBus(NS.MSG.OUTFIT_WORN, id, opts.layer, opts.byTrigger) end
    if opts.hw then St.UpdateTitle(true) end
end

--- Wear an outfit. `opts = { layer, byTrigger, now, hw, clearDisabled }` (design §5.8).
--- @param id string
--- @param opts table|nil
--- @return boolean  false for an id that is not an outfit
function St.Wear(id, opts)
    if not getRec(id) then return false end
    opts = opts or {}
    local batch = opts.now and NS.Equip.BatchNow or NS.Equip.Batch
    batch(wearBody, id, opts)
    return true
end

-- ── remove ────────────────────────────────────────────────────────────────────────────────────

local function removeBody(id, opts)
    local rec = getRec(id)
    table.remove(stack(), indexOf(id))
    collapseTemps()
    local complete = isComplete(rec)
    if complete then
        unlinkRecent(id)
        table.insert(store().recent, 1, id)
    end
    if selectedId == id then St.Select(nil) end
    local r = runtime(id)
    r.didEquip, r.didUnequip = false, opts.byTrigger and true or false
    NS.Equip.Request()
    NS.SendBus(NS.MSG.OUTFIT_REMOVED, id, opts.byTrigger)
    if opts.hw then St.UpdateTitle(true) end
    if complete then wearFallbackComplete() end
end

--- Take an outfit off the stack. `opts = { byTrigger, now, hw }`. A quiet no-op (false) for an id
--- that is not on it: NS.Outfits.Delete calls this unconditionally.
--- @param id string
--- @param opts table|nil
--- @return boolean
function St.Remove(id, opts)
    -- HACK: Disabling the unequipping of Complete outfits to see it works better
    -- for more end-user situations

    -- UPDATE: It doesn't :(  Stealth, riding and other gear as Complete outfits
    -- fail to unequip

    --if pOutfit.CategoryID == "Complete" then
    --	return
    --end
    if not indexOf(id) then return false end
    opts = opts or {}
    local batch = opts.now and NS.Equip.BatchNow or NS.Equip.Batch
    batch(removeBody, id, opts)
    return true
end

--- Wear it, or take it off if worn. A Complete outfit is always re-worn (INV §3.2).
--- @param id string
--- @param opts table|nil
--- @return boolean worn
function St.Toggle(id, opts)
    if St.IsWorn(id) and not isComplete(getRec(id)) then
        St.Remove(id, opts)
        return false
    end
    return St.Wear(id, opts)
end

--- The key binding (design §4.4): a repeat of the same key within 0.75 s is ignored, and its clock
--- refreshes on every press (INV §5, §16 #17). A Complete outfit is worn now; anything else toggles.
--- @param n number
--- @return boolean|nil worn  nil when nothing was done
--- @return table|nil rec
--- @return boolean|nil ignored  true for an ignored repeat
function St.WearBound(n)
    local now = Compat.GetTime()
    if lastBinding.n == n and now - lastBinding.at < BINDING_REPEAT then
        lastBinding.at = now
        return nil, nil, true
    end
    local id = NS.Outfits.BoundTo(n)
    if not id then return nil end
    local rec = getRec(id)
    local worn
    if isComplete(rec) then
        worn = St.Wear(id, { now = true, hw = true, clearDisabled = true })
    else
        worn = St.Toggle(id, { hw = true, clearDisabled = true })
    end
    lastBinding.n, lastBinding.at = n, now
    return worn, rec
end

-- ── reads ─────────────────────────────────────────────────────────────────────────────────────

--- @param id string
--- @return boolean
function St.IsWorn(id) return indexOf(id) ~= nil end

--- The topmost entry's outfit id; nil for an empty stack or a temp on top.
--- @return string|nil
function St.Top()
    local top = topLive()
    return top and top.id or nil
end

--- The Complete outfit on the stack (the lowest), or nil.
--- @return string|nil
function St.CurrentComplete()
    for _, entry in ipairs(stack()) do
        if entry.id and isComplete(getRec(entry.id)) then return entry.id end
    end
    return nil
end

--- `""` for an empty stack, `L["Custom"]` for a temp on top, else the top outfit's name and id
--- (OutfitterEquipment.lua:1301).
--- @return string name
--- @return string|nil id
function St.CurrentInfo()
    local top = topLive()
    if not top then return "", nil end
    if top.temp then return L["Custom"], nil end
    return getRec(top.id).name, top.id
end

--- The launcher's and the bar's label: the current outfit, or None.
--- @return string
function St.CurrentLabel()
    local name = St.CurrentInfo()
    if name == "" then return L["None"] end
    return name
end

--- Whether a trigger put the outfit on / took it off (the smart-unequip reads).
function St.DidEquip(id) return rt[id] ~= nil and rt[id].didEquip == true end
function St.DidUnequip(id) return rt[id] ~= nil and rt[id].didUnequip == true end

-- ── compile ───────────────────────────────────────────────────────────────────────────────────

local function overlay(items, skip)
    for _, entry in ipairs(stack()) do
        if entry ~= skip and (skip == nil or entry.id == nil or entry.id ~= skip) then
            for slot, item in pairs(entryItems(entry) or {}) do items[slot] = item end
        end
    end
    return items
end

--- The stack's own items, bottom to top, with no worn base (GetExpectedOutfit): what the stack
--- below a temp already expects. `skip` is an entry (a temp) or an outfit id left out.
--- @param skip table|string|nil
--- @return table items
function St.Layered(skip)
    return overlay({}, skip)
end

-- Under a two-hander the player cannot grip one-handed, the off-hand is empty (AdjustOffhandSlot,
-- OutfitterOutfits.lua:157).
local function adjustOffhand(items)
    local mh = items.MainHandSlot
    if mh and mh.id ~= 0 and NS.ItemInfo.UsesBothHands(mh) then items.SecondaryHandSlot = NS.ItemInfo.EMPTY end
end

--- What the update equips (GetCompiledOutfit, Outfitter.lua:4035-4070): the worn gear (the empty
--- marker for an empty slot), then each entry's items bottom to top, then the off-hand rule.
--- @param excludeId string|nil  an outfit left out
--- @return table items  slot -> ItemRecord
function St.Compile(excludeId)
    local items = {}
    local worn = NS.Inventory.Cache().worn
    for _, slot in ipairs(ID.SLOT_NAMES) do
        local info = worn[slot]
        items[slot] = info and NS.ItemInfo.Snapshot(info) or NS.ItemInfo.EMPTY
    end
    overlay(items, excludeId)
    adjustOffhand(items)
    return items
end

--- The expected outfit (session): what the last update compiled, plus what the Watch saw since.
--- @return table
function St.Expected() return expected end

--- @param items table
function St.SetExpected(items) expected = items or {} end

-- ── clear, init, lifecycle ────────────────────────────────────────────────────────────────────

--- Empty the stack, announcing OUTFIT_REMOVED for each outfit on it.
function St.Clear()
    local s = stack()
    for i = #s, 1, -1 do
        announceRemoved(table.remove(s, i))
    end
end

local function restoreStack()
    local out = {}
    for _, entry in ipairs(stack()) do
        if type(entry.temp) == "table" or (entry.id and getRec(entry.id)) then out[#out + 1] = entry end
    end
    store().stack = out
end

--- The LoadPass restore: drop unknown ids, keep the temps whole, and expect the compiled stack.
function St.Init()
    restoreStack()
    St.SetExpected(St.Compile())
    St.__watchReset()
end

--- The lifecycle's stand-down (design §5.12): the bus record drops the Watch's receiver; the
--- selection and the anti-panic clock go.
function St.Suspend()
    selectedId = nil
    lastBinding = {}
end

--- The stand-up: the Watch's receiver (once), and the expected outfit recomputed from the current
--- gear. It does not force an equip.
function St.Resume()
    St.__watchInstall()
    St.SetExpected(St.Compile())
    St.__watchReset()
end
