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

-- The sheet's three columns (sheet and window feedback design G7-G8): each box sits on the slot's
-- inner corner, so LEFT and BOTTOM boxes anchor TOPRIGHT (+2, +2) and RIGHT boxes TOPLEFT (-2, +2).
local LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
               "WristSlot" }
local RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot",
                "Trinket1Slot" }
local BOTTOM = { "MainHandSlot", "SecondaryHandSlot" }
local function asSet(list)
    local out = {}
    for _, v in ipairs(list) do out[v] = true end
    return out
end
local IS_RIGHT = asSet(RIGHT)

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

test("slot enables: one 14x14 checkbox per slot, anchored to Character<Slot> (old test_xml:101-112)", function()
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
        if IS_RIGHT[slot] then
            assertEqual(p[1], "TOPLEFT", slot); assertEqual(p[3], "TOPLEFT", slot)
            assertEqual(p[4], -2, slot); assertEqual(p[5], 2, slot)
        else
            assertEqual(p[1], "TOPRIGHT", slot); assertEqual(p[3], "TOPRIGHT", slot)
            assertEqual(p[4], 2, slot); assertEqual(p[5], 2, slot)
        end
    end
    assertEqual(n, 18)
    assertEqual(M.OutfitterRebornSlotEnables:GetParent(), M.OutfitterRebornSheetHolder)
end)

test("slot enables: boxes are 14 px", function()
    -- The mock records no geometry, so each box's SetSize is recorded as it is built (lazily, in Show).
    local NS, M = scene()
    local sizes = {}
    local create = M.CreateFrame
    M.CreateFrame = function(kind, name, ...)
        local f = create(kind, name, ...)
        if kind == "CheckButton" and type(name) == "string" and name:find("^OutfitterRebornEnable") then
            local setSize = f.SetSize
            rawset(f, "SetSize", function(self, w, h) sizes[name] = { w, h }; return setSize(self, w, h) end)
        end
        return f
    end
    M.__world:openCharacter()
    NS.Dock.Open()
    NS.Stack.Select(NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } }))
    M.CreateFrame = create
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        local sz = sizes["OutfitterRebornEnable" .. slot]
        assertTrue(sz ~= nil, slot .. " was never sized")
        -- red under: the old 24x24 SetSize in SlotEnables.lua's newBox.
        assertEqual(sz[1], 14, slot); assertEqual(sz[2], 14, slot)
    end
end)

test("slot enables: the columns are the sheet's, eighteen slots in three", function()
    local NS = selected()
    local col = NS.SlotEnables.COLUMN
    assertEqual(type(col), "table")
    for _, slot in ipairs(LEFT) do assertEqual(col[slot], "LEFT", slot) end
    for _, slot in ipairs(RIGHT) do assertEqual(col[slot], "RIGHT", slot) end
    for _, slot in ipairs(BOTTOM) do assertEqual(col[slot], "BOTTOM", slot) end
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do assertTrue(col[slot] ~= nil, slot .. " has no column") end
end)

test("slot enables: Hands is in the right column and its box is top-left", function()
    local NS, M = selected()
    -- red under: the old RIGHT_SIDE (rings and trinkets only), which put Hands-Feet on the left.
    assertEqual(NS.SlotEnables.COLUMN.HandsSlot, "RIGHT")
    local p = box(M, "HandsSlot").__pts[1]
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], M.CharacterHandsSlot); assertEqual(p[3], "TOPLEFT")
    assertEqual(p[4], -2); assertEqual(p[5], 2)
end)

test("slot enables: Head's box is top-right", function()
    local _, M = selected()
    local p = box(M, "HeadSlot").__pts[1]
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[2], M.CharacterHeadSlot); assertEqual(p[3], "TOPRIGHT")
    assertEqual(p[4], 2); assertEqual(p[5], 2)
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

test("drawer: the window's show and hide tell the drawer, with the window's state already set", function()
    local NS, M = scene()
    local seen = {}
    local sync = NS.QuickSlots.DrawerSync
    NS.QuickSlots.DrawerSync = function() seen[#seen + 1] = NS.Dock.IsShown(); return sync() end
    M.__world:openCharacter()
    NS.Dock.Open()
    -- red under: drop the DrawerSync call from Dock's window OnShow / OnHide hooks.
    assertEqual(#seen, 1, "the window's show did not reach the drawer")
    assertTrue(seen[1], "the drawer ran before the window was shown")
    NS.Dock.Close()
    assertEqual(#seen, 2, "the window's hide did not reach the drawer")
    assertFalse(seen[2], "the drawer ran before the window was hidden")
    NS.QuickSlots.DrawerSync = sync
end)

-- ── host strata (smoke round 2 design G3) ───────────────────────────────────────────────────────
--
-- ChonkyCharacterSheet puts every Character<Slot> button in HIGH strata and leaves CharacterFrame
-- MEDIUM (Chonky core/utils.lua:2059), and raises its model scene to MEDIUM 9000
-- (Retail/characterSheet.lua:57-58); EllesmereUI raises CharacterFrame itself to HIGH. The boxes take
-- the highest strata among the sheet and its slots, and a level over the frames of THAT strata only.

local SLOT_STRATA = "HIGH"      -- Chonky's slot strata: a host value, never one of ours (C.LAYERS)

-- Every slot button re-strataed by the host at `level`, the head one at `head` when given.
local function chonkySlots(NS, M, level, head)
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        local b = M["Character" .. slot]
        b:SetFrameStrata(SLOT_STRATA)
        b:SetFrameLevel(level)
    end
    if head then M.CharacterHeadSlot:SetFrameLevel(head) end
end

test("slot enables: the layers carry the client's strata order, low to high, and a level cap", function()
    local C = T.NS.Constants.LAYERS
    assertEqual(table.concat(C.STRATA_ORDER, ","),
        "BACKGROUND,LOW,MEDIUM,HIGH,DIALOG,FULLSCREEN,FULLSCREEN_DIALOG,TOOLTIP")
    for i, s in ipairs(C.STRATA_ORDER) do assertEqual(C.STRATA_RANK[s], i, s) end
    assertTrue(C.LEVEL.MAX < 10000, "the cap is under the client's level ceiling")
end)

test("slot enables: HostStrata is the highest of CharacterFrame's and the slot buttons'", function()
    local NS, M = selected()
    assertEqual(NS.SlotEnables.HostStrata(), "MEDIUM", "the stock sheet")
    M.CharacterHeadSlot:SetFrameStrata(SLOT_STRATA)
    -- red under: read CharacterFrame's strata alone (the boxes stay MEDIUM under Chonky's HIGH slots).
    assertEqual(NS.SlotEnables.HostStrata(), SLOT_STRATA, "a HIGH slot")
    local get = M.CharacterHeadSlot.GetFrameStrata
    rawset(M.CharacterHeadSlot, "GetFrameStrata", function() error("forbidden") end)
    assertEqual(NS.SlotEnables.HostStrata(), "MEDIUM", "a raising read counts for nothing")
    M.CharacterHeadSlot.GetFrameStrata = get
    M.CharacterFrame:SetFrameStrata(RAISED_HOST_STRATA)
    assertEqual(NS.SlotEnables.HostStrata(), RAISED_HOST_STRATA, "EllesmereUI's HIGH sheet")
end)

test("slot enables: HIGH slots under a MEDIUM sheet lift the boxes to HIGH, over the HIGH frames only", function()
    local NS, M = selected()
    chonkySlots(NS, M, 15, 20)
    NS.SlotEnables.Restack()
    local frame = M.OutfitterRebornSlotEnables
    -- red under: frame:SetFrameStrata(CharacterFrame:GetFrameStrata()) (MEDIUM, under every slot).
    assertEqual(frame:GetFrameStrata(), SLOT_STRATA)
    -- red under: an unfiltered HighestLevel (the MEDIUM sheet button at 510 would set the level).
    assertEqual(frame:GetFrameLevel(), 20 + NS.Constants.LAYERS.LEVEL.SLOT_ENABLES_OVER_HOST)
    assertEqual(M.OutfitterRebornEnableHeadSlot:GetFrameLevel(), frame:GetFrameLevel() + 1)
end)

test("slot enables: a MEDIUM 9000 model scene no longer inflates the boxes' level", function()
    local NS, M = selected()
    local scene9000 = M.CreateFrame("Frame", nil, M.CharacterFrame)
    scene9000:SetFrameLevel(9000)
    chonkySlots(NS, M, 12)
    NS.SlotEnables.Restack()
    -- red under: count every frame's level whatever its strata.
    assertEqual(M.OutfitterRebornSlotEnables:GetFrameLevel(), 13)
    assertEqual(NS.SlotEnables.HighestLevel(M.CharacterFrame, M.OutfitterRebornSheetHolder, SLOT_STRATA), 12)
    assertEqual(NS.SlotEnables.HighestLevel(M.CharacterFrame, M.OutfitterRebornSheetHolder), 9000,
        "no strata: every frame counts, as before")
end)

test("slot enables: the level is capped under the client's ceiling", function()
    local NS, M = selected()
    chonkySlots(NS, M, 9999)
    NS.SlotEnables.Restack()
    -- red under: no math.min against LAYERS.LEVEL.MAX.
    assertEqual(M.OutfitterRebornSlotEnables:GetFrameLevel(), NS.Constants.LAYERS.LEVEL.MAX)
end)

test("slot enables: MaybeRestack restacks on a strata-only change, and once", function()
    local NS, M = selected()
    local frame = M.OutfitterRebornSlotEnables
    local writes = 0
    local setLevel = frame.SetFrameLevel
    frame.SetFrameLevel = function(...) writes = writes + 1; return setLevel(...) end
    chonkySlots(NS, M, 15)
    -- red under: a MaybeRestack that compares CharacterFrame's level only (Chonky's lazy HIGH is missed).
    NS.SlotEnables.MaybeRestack()
    assertEqual(writes, 1)
    assertEqual(frame:GetFrameStrata(), SLOT_STRATA)
    NS.SlotEnables.MaybeRestack()
    assertEqual(writes, 1, "a steady host restacks nothing")
    frame.SetFrameLevel = setLevel
end)

test("slot enables: each box carries an edge in the skin's accent", function()
    local NS, M = scene()
    local marks = {}
    local mark = NS.Skin.Mark
    NS.Skin.Mark = function(tex, opts)
        if type(opts) == "table" and opts.token == "text.accent" then marks[#marks + 1] = tex end
        return mark(tex, opts)
    end
    M.__world:openCharacter()
    NS.Dock.Open()
    NS.Stack.Select(NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } }))
    NS.Skin.Mark = mark
    -- red under: newBox without the edge (the 1 px near-black check.border alone, hard to see).
    assertEqual(#marks, 4 * 18, "four accent sides per box")
    assertTrue(M.OutfitterRebornEnableHeadSlot.edge ~= nil, "the box keeps its edge")
end)
