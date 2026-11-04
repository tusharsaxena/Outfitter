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
-- take the HOST's strata and one level above its highest frame of that strata instead, and follow it
-- as it is raised, lowered or re-strataed (MaybeRestack, from the dock's follow tick). The host's
-- strata is the highest of CharacterFrame's and the 18 Character<Slot> buttons' (smoke round 2 design
-- G3): ChonkyCharacterSheet puts every slot button in HIGH under a MEDIUM CharacterFrame (Chonky
-- core/utils.lua:2059), where no level in MEDIUM can clear them, and raises its model scene to MEDIUM
-- 9000, which a level search across strata would count; EllesmereUI raises CharacterFrame itself to
-- HIGH. The level search still descends through every frame, since Chonky's HIGH slots sit under
-- MEDIUM parents, and the level is capped at LAYERS.LEVEL.MAX. Chonky sets its strata lazily and
-- defers its setup in combat, so a strata change restacks as a level change does. The holder is
-- skipped because the boxes are in it. They hold no secure frame, so unlike the window this is
-- allowed in combat. They are first stacked in Show, not at build: the sheet's level only means
-- something once the sheet is shown.
--
-- THE EDGE. Each box carries a 1 px edge in the skin's accent (`text.accent`, through S.Mark, so a
-- skin switch repaints it) over the skin's checkbox: the box alone is near-black on dark item icons.
--
-- CALLS (at call time; design §12): NS.Dock.Holder, NS.Stack.Selected, NS.Outfits.SlotState/
-- SetSlotEnabled/UnknownSlots, NS.Inventory.Cache, NS.Compat.PickupInventoryItem/InventorySlotID.

local SE = {}
NS.SlotEnables = SE

local LAYERS = NS.Constants.LAYERS
local LEVEL, STRATA_RANK = LAYERS.LEVEL, LAYERS.STRATA_RANK

-- The sheet's three slot columns (sheet and window feedback design G8). Each box sits on the slot's
-- inner corner: LEFT and BOTTOM boxes at TOPRIGHT, RIGHT boxes at TOPLEFT. NS.QuickSlots reads the LEFT
-- column at call time for the outward drawer.
local COLUMN = {
    HeadSlot = "LEFT", NeckSlot = "LEFT", ShoulderSlot = "LEFT", BackSlot = "LEFT", ChestSlot = "LEFT",
    ShirtSlot = "LEFT", TabardSlot = "LEFT", WristSlot = "LEFT",
    HandsSlot = "RIGHT", WaistSlot = "RIGHT", LegsSlot = "RIGHT", FeetSlot = "RIGHT", Finger0Slot = "RIGHT",
    Finger1Slot = "RIGHT", Trinket0Slot = "RIGHT", Trinket1Slot = "RIGHT",
    MainHandSlot = "BOTTOM", SecondaryHandSlot = "BOTTOM",
}
SE.COLUMN = COLUMN
local BOX_SIZE, BOX_INSET = 14, 2
local MAX_DEPTH = 12

local frame
local order = {}           -- the checkboxes, in SLOT_NAMES order
local hostLevel, hostProbe  -- the sheet's level and strata probe at the last Restack
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

-- A frame's strata, plain and one the client has, or nil.
local function strataOf(f)
    if type(f) ~= "table" then return nil end
    local ok, v = pcall(f.GetFrameStrata, f)
    local s = ok and NS.Secrets.PlainString(v) or nil
    if s and STRATA_RANK[s] then return s end
    return nil
end

--- The highest frame level under `root`, the `skip` subtree and forbidden frames left out. With
--- `strata`, only frames of that strata count, but every frame is still descended into.
--- Iterative, MAX_DEPTH deep; every read through pcall and SafeNumber.
--- @param root table
--- @param skip table|nil
--- @param strata string|nil
--- @return number
function SE.HighestLevel(root, skip, strata)
    local best = 0
    local frames, depths = { root }, { 0 }
    while #frames > 0 do
        local f, depth = table.remove(frames), table.remove(depths)
        if f ~= skip and not forbidden(f) then
            local lv = levelOf(f)
            if lv > best and (strata == nil or strataOf(f) == strata) then best = lv end
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

--- The host's strata: the highest-ranked of CharacterFrame's and the 18 slot buttons' (a read that
--- raises, or answers no strata, counts for nothing); nil when none answers, never a literal stand-in
--- (frame-layering-§1: a host-matched surface reads its host's strata).
--- @return string|nil
function SE.HostStrata()
    local best = strataOf(CharacterFrame)
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        local s = strataOf(_G["Character" .. slot])
        if s and (best == nil or STRATA_RANK[s] > STRATA_RANK[best]) then best = s end
    end
    return best
end

-- The cheap per-tick probe of the host's strata: the sheet's and one slot's (a host re-strataes its
-- slots together, Chonky core/utils.lua:2059).
local function strataProbe()
    return (strataOf(CharacterFrame) or "") .. "/" .. (strataOf(_G.CharacterHeadSlot) or "")
end

--- Take the host's strata and one level above its highest descendant of that strata, capped. A host
--- that answers no strata leaves the boxes the one they inherit, over every descendant's level.
function SE.Restack()
    if not frame then return end
    hostLevel = NS.SafeNumber(CharacterFrame:GetFrameLevel(), 0)
    hostProbe = strataProbe()
    local strata = SE.HostStrata()
    if strata then frame:SetFrameStrata(strata) end
    local level = SE.HighestLevel(CharacterFrame, NS.Dock.Holder(), strata) + LEVEL.SLOT_ENABLES_OVER_HOST
    frame:SetFrameLevel(math.min(level, LEVEL.MAX))
    SE.Relevel()
end

--- Restack only when the sheet's level or the host's strata moved (the follow tick calls this; no
--- steady-state cost).
function SE.MaybeRestack()
    if not (frame and frame:IsShown()) then return end
    if NS.SafeNumber(CharacterFrame:GetFrameLevel(), 0) ~= hostLevel or strataProbe() ~= hostProbe then
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

-- The four 1 px sides, from the box's outer edge in: white the accent tints (S.Mark), over the box.
local WHITE = "Interface\\Buttons\\WHITE8X8"
local EDGE = {
    { "TOPLEFT", "TOPRIGHT", "SetHeight" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
    { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
}

local function accentEdge(cb)
    local sides = {}
    for i, e in ipairs(EDGE) do
        local t = cb:CreateTexture(nil, "ARTWORK")
        t:SetPoint(e[1], cb, e[1])
        t:SetPoint(e[2], cb, e[2])
        t[e[3]](t, 1)
        t:SetTexture(WHITE)
        NS.Skin.Mark(t, { token = "text.accent" })
        sides[i] = t
    end
    return sides
end

local function newBox(slot)
    local cb = CreateFrame("CheckButton", "OutfitterRebornEnable" .. slot, frame)
    cb:SetSize(BOX_SIZE, BOX_SIZE)
    local anchor = _G["Character" .. slot]
    if COLUMN[slot] == "RIGHT" then
        cb:SetPoint("TOPLEFT", anchor, "TOPLEFT", -BOX_INSET, BOX_INSET)
    else
        cb:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", BOX_INSET, BOX_INSET)
    end
    cb.slot = slot
    NS.Skin.Checkbox(cb, { hover = true })
    cb.edge = accentEdge(cb)
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
