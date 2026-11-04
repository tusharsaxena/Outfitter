local _, NS = ...
-- modules/SlotEnables.lua — NS.SlotEnables: the 18 slot checkboxes over the character sheet while an
-- outfit is selected (design §7.4, INV §7.3, §16.2).
--
-- A VIEW ONLY. Each box's state is NS.Outfits.SlotState (off, on, unknown) and each write goes through
-- NS.Outfits; the data layer reads the outfit's items, never these frames (which retires the old
-- readers at OutfitterOutfits.lua:50, 538, 558). CharacterLevelText is left alone.
--
-- STACKING (Outfitter.lua:1451-1456). The boxes sit on top of the sheet's item buttons, and on top of
-- anything another addon draws over the sheet, so they need a level above everything in it. A fixed
-- high level or strata does that but also pokes them through any window covering the sheet, so they
-- take the sheet's strata and one level above its highest frame instead, and follow it as it is
-- raised and lowered (MaybeRestack, from the dock's follow tick). The holder is skipped because the
-- boxes are in it. They hold no secure frame, so unlike the window this is allowed in combat.
-- They are first stacked in Show, not at build: the sheet's level only means something once the
-- sheet is shown.
--
-- CALLS (at call time; design §12): NS.Dock.Holder, NS.Stack.Selected, NS.Outfits.SlotState/
-- SetSlotEnabled/UnknownSlots, NS.Inventory.Cache, NS.Compat.PickupInventoryItem/InventorySlotID.

local SE = {}
NS.SlotEnables = SE

local LEVEL = NS.Constants.LAYERS.LEVEL

-- The boxes that anchor at the slot button's TOPRIGHT: the right-hand column and the weapons.
local RIGHT_SIDE = { Finger0Slot = true, Finger1Slot = true, Trinket0Slot = true, Trinket1Slot = true,
                     MainHandSlot = true, SecondaryHandSlot = true }
local MAX_DEPTH = 12

local frame
local order = {}           -- the checkboxes, in SLOT_NAMES order
local hostLevel
local installed = false

local function cursorHasItem()
    return type(CursorHasItem) == "function" and NS.Secrets.PlainTruth(CursorHasItem()) == true
end

-- ── stacking ──────────────────────────────────────────────────────────────────────────────────

local function levelOf(f)
    local ok, v = pcall(f.GetFrameLevel, f)
    return ok and NS.SafeNumber(v, 0) or 0
end

local function forbidden(f)
    local ok, v = pcall(f.IsForbidden, f)
    return ok and v == true
end

local function pushChildren(f, depth, frames, depths)
    local kids = { pcall(f.GetChildren, f) }
    if not kids[1] then return end
    for i = 2, #kids do
        if type(kids[i]) == "table" then
            frames[#frames + 1], depths[#depths + 1] = kids[i], depth + 1
        end
    end
end

--- The highest frame level under `root`, the `skip` subtree and forbidden frames left out.
--- Iterative, MAX_DEPTH deep; every read through pcall and SafeNumber.
--- @param root table
--- @param skip table|nil
--- @return number
function SE.HighestLevel(root, skip)
    local best = 0
    local frames, depths = { root }, { 0 }
    while #frames > 0 do
        local f, depth = table.remove(frames), table.remove(depths)
        if f ~= skip and not forbidden(f) then
            local lv = levelOf(f)
            if lv > best then best = lv end
            if depth < MAX_DEPTH then pushChildren(f, depth, frames, depths) end
        end
    end
    return best
end

--- The boxes one level up inside the container (frame-layering-§3).
function SE.Relevel()
    if not frame then return end
    local base = NS.SafeNumber(frame:GetFrameLevel(), 0) + LEVEL.SLOT_CHECKBOX
    for _, cb in ipairs(order) do cb:SetFrameLevel(base) end
end

--- Take CharacterFrame's strata and one level above its highest descendant.
function SE.Restack()
    if not frame then return end
    hostLevel = NS.SafeNumber(CharacterFrame:GetFrameLevel(), 0)
    frame:SetFrameStrata(CharacterFrame:GetFrameStrata())
    frame:SetFrameLevel(SE.HighestLevel(CharacterFrame, NS.Dock.Holder()) + LEVEL.SLOT_ENABLES_OVER_HOST)
    SE.Relevel()
end

--- Restack only when the sheet's level moved (the follow tick calls this; no steady-state cost).
function SE.MaybeRestack()
    if frame and frame:IsShown() and NS.SafeNumber(CharacterFrame:GetFrameLevel(), 0) ~= hostLevel then
        SE.Restack()
    end
end

-- ── state ─────────────────────────────────────────────────────────────────────────────────────

--- Redraw every box from the selected outfit.
function SE.Update()
    if not (frame and frame:IsShown()) then return end
    local sel = NS.Stack.Selected()
    if not sel then return end
    local cache = NS.Inventory.Cache()
    for _, cb in ipairs(order) do
        local state = NS.Outfits.SlotState(sel, cb.slot, cache)
        cb.state = state
        cb:SetChecked(state == "on")
        cb.unknown:SetShown(state == "unknown")
    end
end

--- The selected outfit's slots in the "unknown" state (window-open recording reads it).
--- @return table slot -> true
function SE.UnknownSlots()
    return NS.Outfits.UnknownSlots(NS.Stack.Selected(), NS.Inventory.Cache())
end

-- An item on the cursor goes into the slot (Outfitter.lua:3333-3356); the box shows the outfit again.
local function dropCursor(cb)
    NS.Compat.PickupInventoryItem(NS.Compat.InventorySlotID(cb.slot))
    SE.Update()
end

local function onClick(cb)
    if NS.IsStoodDown() then return end
    local sel = NS.Stack.Selected()
    if cursorHasItem() then return dropCursor(cb) end
    if not sel then return end
    NS.Outfits.SetSlotEnabled(sel, cb.slot, cb:GetChecked() == true)
end

local function onReceiveDrag(cb)
    if NS.IsStoodDown() or not cursorHasItem() then return end
    dropCursor(cb)
end

-- ── build ─────────────────────────────────────────────────────────────────────────────────────

local function newBox(slot)
    local cb = CreateFrame("CheckButton", "OutfitterRebornEnable" .. slot, frame)
    cb:SetSize(24, 24)
    local anchor = _G["Character" .. slot]
    if RIGHT_SIDE[slot] then
        cb:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 4, 4)
    else
        cb:SetPoint("TOPLEFT", anchor, "TOPLEFT", -4, 4)
    end
    cb.slot = slot
    NS.Skin.Checkbox(cb, { hover = true })
    cb.unknown = cb:CreateTexture(nil, "OVERLAY")
    cb.unknown:SetAllPoints(cb)
    cb.unknown:SetTexture(NS.Icon("help"))
    NS.Skin.Mark(cb.unknown, { token = "of.slot.unknown" })
    cb.unknown:Hide()
    cb:SetScript("OnClick", onClick)
    cb:SetScript("OnReceiveDrag", onReceiveDrag)
    return cb
end

--- Build the container and the boxes, once, hidden. No stacking here (see the header).
--- @return table the container
function SE.Build()
    if frame then return frame end
    local holder = NS.Dock.Holder()
    frame = CreateFrame("Frame", "OutfitterRebornSlotEnables", holder)
    frame:SetAllPoints(holder)
    frame:Hide()
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        order[#order + 1] = newBox(slot)
    end
    return frame
end

--- Show the boxes for `id` (the selection), stacking them first.
--- @param id string
function SE.Show(id)
    if NS.IsStoodDown() or not id then return end
    SE.Build()
    frame:Show()
    SE.Restack()
    SE.Update()
end

function SE.Hide()
    if frame then frame:Hide() end
end

local function onSelection(_, id)
    if id then SE.Show(id) else SE.Hide() end
end

--- The bus receivers, once per session.
function SE.Install()
    if installed then return end
    installed = true
    local bus = NS.NewBusTarget()
    if not bus then return end
    bus:RegisterMessage(NS.MSG.SELECTION_CHANGED, onSelection)
    bus:RegisterMessage(NS.MSG.OUTFIT_EDITED, SE.Update)
    bus:RegisterMessage(NS.MSG.INVENTORY_CHANGED, SE.Update)
end

--- The lifecycle's stand-down (design §5.12): the boxes hide; the bus record drops the receivers.
function SE.Suspend()
    SE.Hide()
end

--- The stand-up: the receivers, once.
function SE.Resume()
    SE.Install()
end
