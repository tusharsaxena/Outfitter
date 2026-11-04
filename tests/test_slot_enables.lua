-- tests/test_slot_enables.lua — P4.19 (design §7.4, INV §7.3, §16.2): modules/SlotEnables.lua, the
-- slot checkboxes over the character sheet while an outfit is selected.
--
-- A view only: every state comes from NS.Outfits.SlotState and every write goes through
-- NS.Outfits. Stacked from the sheet (CharacterFrame's strata, one level above its highest
-- descendant) the first time they show, and again only when the sheet's level moves. The port of
-- the old test_xml:101-112 anchor check is the first case.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local scene = dofile(T.root .. "/tests/dock_scene.lua")(T)
-- The fake sheet re-strataed by the host: a host value, never one of ours (C.LAYERS).
local RAISED_HOST_STRATA = "HIGH"

-- The six boxes that anchor at the slot's TOPRIGHT (the right-hand column and the weapons).
local RIGHT = { Finger0Slot = true, Finger1Slot = true, Trinket0Slot = true, Trinket1Slot = true,
                MainHandSlot = true, SecondaryHandSlot = true }

-- The window open with an outfit that uses the head (worn) and the chest (an item not worn), selected.
local function selected()
    local NS, M, fakes = scene()
    M.__world:openCharacter()
    NS.Dock.Open()
    local chest = NS.ItemInfo.Snapshot(NS.ItemInfo.FromBag(0, 5))
    local head = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot"))
    local id = NS.Outfits.Create("Hero", { HeadSlot = head, ChestSlot = chest })
    NS.Stack.Select(id)
    return NS, M, id, fakes
end

local function box(M, slot) return M["OutfitterRebornEnable" .. slot] end

test("slot enables: NS.SlotEnables is published with the §7.4 surface", function()
    local SE = T.NS.SlotEnables
    assertEqual(type(SE), "table")
    for _, k in ipairs({ "Show", "Hide", "Update", "Restack", "MaybeRestack", "HighestLevel", "Relevel",
                         "UnknownSlots", "Install", "Suspend", "Resume" }) do
        assertEqual(type(SE[k]), "function", k)
    end
end)

test("slot enables: one 24x24 checkbox per slot, anchored to Character<Slot> (old test_xml:101-112)", function()
    local NS, M = selected()
    local n = 0
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        local cb = box(M, slot)
        assertTrue(cb ~= nil, "no checkbox for " .. slot)
        n = n + 1
        assertEqual(cb:GetParent(), M.OutfitterRebornSlotEnables)
        local p = cb.__pts[1]
        assertTrue(p ~= nil, slot .. " is not anchored")
        assertEqual(p[2], M["Character" .. slot], slot .. " is not anchored to its slot button")
        if RIGHT[slot] then
            assertEqual(p[1], "TOPRIGHT"); assertEqual(p[4], 4); assertEqual(p[5], 4)
        else
            assertEqual(p[1], "TOPLEFT"); assertEqual(p[4], -4); assertEqual(p[5], 4)
        end
    end
    assertEqual(n, 18)
    assertEqual(M.OutfitterRebornSlotEnables:GetParent(), M.OutfitterRebornSheetHolder)
end)

test("slot enables: the tri-state reads O.SlotState: off, on (worn), unknown (used, not worn)", function()
    local _, M = selected()
    local head, chest, legs = box(M, "HeadSlot"), box(M, "ChestSlot"), box(M, "LegsSlot")
    assertEqual(head.state, "on"); assertTrue(head:GetChecked()); assertFalse(head.unknown:IsShown())
    -- red under: show the unknown mark on "on" too, or check the box for "unknown".
    assertEqual(chest.state, "unknown"); assertFalse(chest:GetChecked()); assertTrue(chest.unknown:IsShown())
    assertEqual(legs.state, "off"); assertFalse(legs:GetChecked()); assertFalse(legs.unknown:IsShown())
end)

test("slot enables: a click writes through NS.Outfits only, and the box follows OUTFIT_EDITED", function()
    local NS, M, id = selected()
    local calls = {}
    local set = NS.Outfits.SetSlotEnabled
    NS.Outfits.SetSlotEnabled = function(...) calls[#calls + 1] = { ... }; return set(...) end
    local legs = box(M, "LegsSlot")
    legs:SetChecked(true); legs:__fire("OnClick", "LeftButton")
    assertEqual(#calls, 1)
    assertEqual(calls[1][1], id); assertEqual(calls[1][2], "LegsSlot"); assertEqual(calls[1][3], true)
    assertTrue(NS.Outfits.Get(id).items.LegsSlot ~= nil, "the slot was not enabled")
    assertEqual(legs.state, "on", "the box did not follow OUTFIT_EDITED")
    legs:SetChecked(false); legs:__fire("OnClick", "LeftButton")
    assertEqual(calls[2][3], false)
    assertEqual(legs.state, "off")
    NS.Outfits.SetSlotEnabled = set
end)

test("slot enables: with an item on the cursor a click drops it into the slot and edits nothing", function()
    local NS, M = selected()
    local picked, edits = {}, 0
    local pickup = NS.Compat.PickupInventoryItem
    NS.Compat.PickupInventoryItem = function(slotID) picked[#picked + 1] = slotID end
    local set = NS.Outfits.SetSlotEnabled
    NS.Outfits.SetSlotEnabled = function(...) edits = edits + 1; return set(...) end
    rawset(M, "CursorHasItem", function() return true end)
    local legs = box(M, "LegsSlot")
    legs:SetChecked(true); legs:__fire("OnClick", "LeftButton")
    legs:__fire("OnReceiveDrag")
    -- red under: drop the CursorHasItem branch (the click edits the outfit).
    assertEqual(edits, 0)
    assertEqual(#picked, 2)
    assertEqual(picked[1], NS.Compat.InventorySlotID("LegsSlot"))
    assertFalse(legs:GetChecked(), "the box kept a check the outfit does not have")
    NS.Compat.PickupInventoryItem, NS.Outfits.SetSlotEnabled = pickup, set
end)

test("slot enables: All and None are named for what they do", function()
    local NS, M, id = selected()
    M.OutfitterRebornSlotsAll:__fire("OnClick", "LeftButton")
    local n = 0
    for _ in pairs(NS.Outfits.Get(id).items) do n = n + 1 end
    -- red under: swap the two buttons' handlers (the old OutfitterEnableAll/None swap).
    assertEqual(n, 18, "All did not enable every slot")
    M.OutfitterRebornSlotsNone:__fire("OnClick", "LeftButton")
    assertEqual(next(NS.Outfits.Get(id).items), nil, "None did not clear every slot")
end)

test("slot enables: the footer's All and None show only while an outfit is selected", function()
    local NS, M = selected()
    NS.Window.Render()
    assertTrue(M.OutfitterRebornSlotsAll:IsShown())
    NS.Stack.Select(nil)
    NS.Window.Render()
    assertFalse(M.OutfitterRebornSlotsAll:IsShown())
    assertFalse(M.OutfitterRebornSlotsNone:IsShown())
    assertFalse(M.OutfitterRebornSlotEnables:IsShown(), "the checkboxes outlived the selection")
end)

test("slot enables: the first Restack is in Show, from the sheet's strata and highest descendant", function()
    local NS, M = scene()
    M.__world:openCharacter()
    NS.Dock.Open()
    NS.SlotEnables.Build()
    local frame = M.OutfitterRebornSlotEnables
    -- red under: call Restack from Build (the level is set before the sheet is shown).
    assertEqual(rawget(frame, "__level"), nil, "stacked at build")
    M.CharacterFrame:SetFrameStrata(RAISED_HOST_STRATA)
    local id = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    NS.Stack.Select(id)
    assertTrue(frame:IsShown())
    assertEqual(frame:GetFrameStrata(), RAISED_HOST_STRATA)
    local highest = NS.SlotEnables.HighestLevel(M.CharacterFrame, M.OutfitterRebornSheetHolder)
    -- The sheet's top frame is the outfit button, set over the close button (510, the title bar's
    -- level; modules/Dock.lua), which is over the slot buttons: the boxes clear all three.
    assertTrue(highest > M.CharacterHeadSlot:GetFrameLevel(), "the boxes do not clear the slot buttons")
    assertEqual(highest, M.OutfitterRebornSheetButton:GetFrameLevel(), "the sheet's top frame")
    assertEqual(frame:GetFrameLevel(), highest + 1)
    assertEqual(M.OutfitterRebornEnableHeadSlot:GetFrameLevel(), frame:GetFrameLevel() + 1)
end)

test("slot enables: MaybeRestack is a no-op while the sheet's level is unchanged", function()
    local NS, M = selected()
    local frame = M.OutfitterRebornSlotEnables
    local writes = 0
    local setLevel = frame.SetFrameLevel
    rawset(frame, "SetFrameLevel", function(...) writes = writes + 1; return setLevel(...) end)
    NS.SlotEnables.MaybeRestack()
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    -- red under: drop the level compare in MaybeRestack (every follow tick restacks).
    assertEqual(writes, 0)
    M.CharacterFrame:SetFrameLevel(40)
    NS.SlotEnables.MaybeRestack()
    assertEqual(writes, 1)
    assertEqual(frame:GetFrameLevel(), NS.SlotEnables.HighestLevel(M.CharacterFrame, M.OutfitterRebornSheetHolder) + 1)
end)

test("slot enables: a secret sheet level reads as 0, through SafeNumber, and never raises", function()
    local NS, M = selected()
    rawset(M.CharacterFrame, "GetFrameLevel", function() return T.secret(12) end)
    -- red under: read CharacterFrame:GetFrameLevel() without NS.SafeNumber in MaybeRestack.
    NS.SlotEnables.MaybeRestack()
    NS.SlotEnables.Restack()
    assertEqual(type(M.OutfitterRebornSlotEnables:GetFrameLevel()), "number")
end)

test("slot enables: UnknownSlots answers the selected outfit's unknown set", function()
    local NS = selected()
    local unknown = NS.SlotEnables.UnknownSlots()
    assertTrue(unknown.ChestSlot); assertEqual(unknown.HeadSlot, nil)
end)

test("slot enables: hidden when stood down, and a selection while down shows nothing", function()
    local NS, M = selected()
    local frame = M.OutfitterRebornSlotEnables
    assertTrue(frame:IsShown())
    NS.SetByPath("enabled", false)
    -- red under: drop the frame:Hide() from SlotEnables.Suspend.
    assertFalse(frame:IsShown())
    NS.SlotEnables.Show(NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } }))
    assertFalse(frame:IsShown(), "a stood-down Show showed the checkboxes")
end)
