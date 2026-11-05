-- tests/test_window_settings.lua — the Outfit Window settings page (smoke round 3 E11,
-- settings/OutfitWindow.lua) and what each of its rows reaches: the sheet button, the slot check boxes
-- and the outward drawer (modules/Dock.lua, modules/SlotEnables.lua, modules/QuickSlots.lua), the dock's
-- gap from the sheet, the item sections (modules/Window_ListModel.lua) and the outfit row's two marks
-- (modules/Window_Rows.lua). Each row follows a write through the seam and a profile switch, which
-- writes no row.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dock_scene.lua")(T)

local PATHS = { "window.sheetButton", "window.slotBoxes", "window.drawer", "window.dockGap",
                "window.sections.unused", "window.sections.warbound", "window.sections.boe",
                "window.marks.em", "window.marks.trigger" }

-- The scene with the sheet laid out at (right 300, top 500) and the window open on it.
local function opened(opts)
    local NS, M, fakes = scene(opts)
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    return NS, M, fakes, M.OutfitterRebornWindow
end

local function tick(M) M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05) end

-- The x of a region's latest LEFT point: the client replaces a point set again, the paint recorder
-- (tests/_kit/mock_paint.lua) appends it.
local function leftX(region)
    local pts = region.__points
    for i = #pts, 1, -1 do
        if pts[i][1] == "LEFT" then return pts[i][4] end
    end
    return nil
end

-- The first row showing an entry of `kind`.
local function rowOf(NS, kind)
    for _, row in ipairs(NS.WindowRows.rows) do
        if row.entry and row.entry.kind == kind then return row end
    end
    return nil
end

-- ── the page ──────────────────────────────────────────────────────────────────────────────────

test("window settings: the page holds the window's rows on two tabs, each with a tooltip", function()
    local NS = T.NS
    local out = {}
    for _, r in ipairs(NS.SchemaForPage("window")) do
        out[#out + 1] = r.path .. "=" .. r.group .. (r.subgroup and ("/" .. r.subgroup) or "")
    end
    -- red under: the List rows registered ahead of the Character sheet rows.
    assertEqual(table.concat(out, ","), "window.sheetButton=Character sheet,window.slotBoxes=Character sheet,"
        .. "window.drawer=Character sheet,window.dockGap=Character sheet,"
        .. "window.sections.unused=List/Item sections,window.sections.warbound=List/Item sections,"
        .. "window.sections.boe=List/Item sections,window.marks.em=List/Outfit rows,"
        .. "window.marks.trigger=List/Outfit rows")
    for _, path in ipairs(PATHS) do
        local row = NS.FindSchemaRow(path)
        assertEqual(type(row.tooltip), "string", path .. " has no tooltip")
        assertTrue(#row.tooltip > 0, path .. " has an empty tooltip")
        assertNil(row.onChange, path .. ": each surface follows the bus, not an onChange")
    end
    -- Every switch on and no gap: the window as it has always looked.
    for _, path in ipairs(PATHS) do
        local want = path == "window.dockGap" and 0 or true
        assertEqual(NS.FindSchemaRow(path).default, want, path)
        assertEqual(NS.GetSetting(path), want, path)
    end
    local gap = NS.FindSchemaRow("window.dockGap")
    assertTrue(gap.min == 0 and gap.max == 40 and gap.step == 1, "the gap's range")
    assertEqual(gap.label, "Gap from the character sheet (px)")
    assertEqual(NS.WINDOW_PAGE.key, "window")
    assertEqual(NS.WINDOW_PAGE.title, "Outfit Window")
    assertEqual(NS.WINDOW_PAGE.panelName, "OutfitterRebornWindowPanel")
    assertEqual(NS.WINDOW_PAGE.defaultsTooltip, "Restore every Outfit Window setting to its default.")
end)

test("window settings: the page's Defaults puts every row back", function()
    local inst = T.load()
    local NS = inst.NS
    for _, path in ipairs(PATHS) do
        assertTrue(NS.SetByPath(path, path == "window.dockGap" and 12 or false), path)
    end
    for _, row in ipairs(NS.SchemaForPage("window")) do NS.ApplyDefault(row) end
    for _, path in ipairs(PATHS) do
        assertEqual(NS.GetSetting(path), path == "window.dockGap" and 0 or true, path)
    end
end)

-- ── the sheet button ──────────────────────────────────────────────────────────────────────────

test("window settings: Show the button on the character sheet hides and shows the sheet button in place", function()
    local NS, M = scene()
    local button = M.OutfitterRebornSheetButton
    M.__world:openCharacter()
    assertTrue(button:IsShown())
    NS.SetByPath("window.sheetButton", false)
    -- red under: no window.* receiver in modules/Dock.lua.
    assertFalse(button:IsShown(), "the button stayed up with its row off")
    -- red under: placeButton's unconditional Show.
    M.PaperDollFrame:Hide(); M.PaperDollFrame:__fire("OnHide")
    M.PaperDollFrame:Show(); M.PaperDollFrame:__fire("OnShow")
    assertFalse(button:IsShown(), "the sheet's next show brought the button back")
    NS.SetByPath("window.sheetButton", true)
    assertTrue(button:IsShown())
    -- Off the paper doll the switch shows nothing.
    M.PaperDollFrame:Hide(); M.PaperDollFrame:__fire("OnHide")
    NS.SetByPath("window.sheetButton", false)
    NS.SetByPath("window.sheetButton", true)
    assertFalse(button:IsShown(), "the switch showed the button off the paper doll")
end)

test("window settings: a profile switch carries the sheet button's row", function()
    local NS, M = scene()
    local button = M.OutfitterRebornSheetButton
    M.__world:openCharacter()
    NS.db:SetProfile("Alt")
    NS.SetByPath("window.sheetButton", false)
    NS.db:SetProfile("Default")
    assertTrue(button:IsShown())
    NS.db:SetProfile("Alt")
    -- red under: no PROFILE_CHANGED receiver in modules/Dock.lua (a switch writes no row).
    assertFalse(button:IsShown(), "the button kept the old profile's state")
    NS.db:SetProfile("Default")
end)

test("window settings: the window still opens without the button", function()
    local NS, M = scene()
    NS.SetByPath("window.sheetButton", false)
    M.__world:openCharacter()
    assertTrue(NS.Dock.Open())
    assertFalse(M.OutfitterRebornSheetButton:IsShown())
end)

-- ── the slot check boxes ──────────────────────────────────────────────────────────────────────

local function selected()
    local NS, M = opened()
    local head = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot"))
    local id = NS.Outfits.Create("Hero", { HeadSlot = head })
    NS.Stack.Select(id)
    return NS, M, id
end

test("window settings: Show slot check boxes hides and shows the boxes for the selection", function()
    local NS, M, id = selected()
    local frame = M.OutfitterRebornSlotEnables
    assertTrue(frame:IsShown())
    NS.SetByPath("window.slotBoxes", false)
    -- red under: no window.slotBoxes receiver in modules/SlotEnables.lua.
    assertFalse(frame:IsShown(), "the boxes stayed up with their row off")
    -- red under: SlotEnables.Show without the row's gate.
    NS.Stack.Select(nil); NS.Stack.Select(id)
    assertFalse(frame:IsShown(), "a new selection showed the boxes")
    NS.SetByPath("window.slotBoxes", true)
    assertTrue(frame:IsShown(), "the row back on did not show them for the selection")
    -- A profile switch writes no row.
    NS.db:SetProfile("Alt")
    NS.SetByPath("window.slotBoxes", false)
    NS.db:SetProfile("Default")
    assertTrue(frame:IsShown())
    NS.db:SetProfile("Alt")
    -- red under: no PROFILE_CHANGED receiver in modules/SlotEnables.lua.
    assertFalse(frame:IsShown(), "the boxes kept the old profile's state")
    NS.db:SetProfile("Default")
end)

-- ── the drawer ────────────────────────────────────────────────────────────────────────────────

-- A popout arrow on every slot button, hidden as Blizzard's template is (EquipmentFlyout.xml:26-37).
local function withArrows(M)
    for name, b in pairs(M.__slotButtons) do
        local popout = M.CreateFrame("Button", nil, b)
        popout:Hide()
        b.verticalFlyout = (name == "MainHandSlot" or name == "SecondaryHandSlot") or nil
        b.popoutButton = popout
    end
end

local function arrowsShown(M)
    local n = 0
    for _, b in pairs(M.__slotButtons) do
        if b.popoutButton:IsShown() then n = n + 1 end
    end
    return n
end

test("window settings: Show the flyout arrows turns the drawer off and on with the window open", function()
    local NS, M = scene({ mutate = withArrows })
    NS.QuickSlots.Resume()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    local total = 0
    for _ in pairs(M.__slotButtons) do total = total + 1 end
    assertEqual(arrowsShown(M), total, "the open window shows every arrow")
    NS.SetByPath("window.drawer", false)
    -- red under: drawerWanted without the row (modules/QuickSlots.lua), or no Dock receiver to sync.
    assertEqual(arrowsShown(M), 0, "the arrows stayed out with the row off")
    local pts = M.__slotButtons.HeadSlot.popoutButton.__pts
    assertEqual(pts[#pts][1], "LEFT", "the left column's arrow is back at Blizzard's anchor")
    NS.SetByPath("window.drawer", true)
    assertEqual(arrowsShown(M), total)
    -- Off, a fresh open leaves Blizzard's arrows alone.
    NS.SetByPath("window.drawer", false)
    NS.Dock.Close(); NS.Dock.Open()
    assertEqual(arrowsShown(M), 0, "the window's show brought the drawer out with its row off")
end)

-- ── the dock's gap ────────────────────────────────────────────────────────────────────────────

test("window settings: the gap moves the docked window right of the sheet, on the follow's next tick", function()
    local NS, M, _, win = opened()
    local p = win.__pts[#win.__pts]
    assertEqual(p[4], 300); assertEqual(p[5], 500)
    NS.SetByPath("window.dockGap", 12)
    tick(M)
    p = win.__pts[#win.__pts]
    -- red under: corner() without the gap (modules/Dock.lua).
    assertEqual(p[4], 312, "the window did not move by the gap")
    assertEqual(p[5], 500, "the gap moved the window's top")
    -- In the sheet's units: on a sheet at 0.8 the gap is 0.8 of its pixels too.
    rawset(M.CharacterFrame, "GetEffectiveScale", function() return 0.8 end)
    NS.SetByPath("window.dockGap", 20)
    tick(M)
    p = win.__pts[#win.__pts]
    assertEqual(p[4], 320 * 0.8)
    NS.SetByPath("window.dockGap", 0)
    tick(M)
    p = win.__pts[#win.__pts]
    assertEqual(p[4], 300 * 0.8)
end)

test("window settings: the alone test window takes no gap", function()
    local NS, M = scene()
    M.__sheets.place(M.UIParent, 1920, 1080)
    NS.SetByPath("window.dockGap", 20)
    NS.Preview.Start()
    local x = NS.Dock.AloneSpot()
    assertTrue(type(x) == "number", "the alone spot needs UIParent's rect")
    local win = M.OutfitterRebornWindow
    local p = win.__pts[#win.__pts]
    assertEqual(p[2], M.UIParent)
    -- red under: the gap added to the alone spot as well as the sheet's corner.
    assertEqual(p[4], x, "the gap moved the alone test window")
    NS.Preview.Stop()
end)

-- ── the list ──────────────────────────────────────────────────────────────────────────────────

-- The list model over a fake store: one outfit and the three item sections.
local function model()
    local NS = T.load().NS
    T.fake(NS, "Outfits", {
        Categories = function() return { "Complete" } end,
        Ids = function() return { "o1" } end,
        Get = function() return { name = "Hat", kind = "native" } end,
        Status = function() return "normal" end,
    })
    T.fake(NS, "Inventory", { ItemSections = function()
        return {
            { key = "unused", labelKey = "Odds 'n ends", items = { { name = "Ring" } } },
            { key = "warbound", labelKey = "Warbound until equipped", items = { { name = "Cloak" } } },
            { key = "boe", labelKey = "Unopened", items = { { name = "Belt" } } },
        }
    end })
    return NS
end

local function categories(entries)
    local out = {}
    for _, e in ipairs(entries) do
        if e.kind == "category" then out[#out + 1] = e.id end
    end
    return table.concat(out, ",")
end

test("window settings: each item section's row keeps it in the list or leaves it out", function()
    local NS = model()
    local LM = NS.WindowListModel
    assertEqual(categories(LM.Build({}, {})), "Complete,unused,warbound,boe")
    NS.SetByPath("window.sections.warbound", false)
    -- red under: Build listing every section Inventory answers.
    assertEqual(categories(LM.Build({}, {})), "Complete,unused,boe")
    NS.SetByPath("window.sections.unused", false)
    NS.SetByPath("window.sections.boe", false)
    assertEqual(categories(LM.Build({}, {})), "Complete", "the outfit categories always stay")
    NS.SetByPath("window.sections.unused", true)
    assertEqual(categories(LM.Build({}, {})), "Complete,unused")
end)

test("window settings: a section's row redraws the open window", function()
    local NS, M = opened()
    local function listed(key)
        for _, e in ipairs(NS.Window.entries) do
            if e.kind == "category" and e.id == key then return true end
        end
        return false
    end
    assertTrue(listed("unused"), "the geared scene lists Odds 'n ends")
    NS.SetByPath("window.sections.unused", false)
    tick(M)
    -- red under: Window's SETTINGS_CHANGED receiver marking only auto.enabled dirty.
    assertFalse(listed("unused"), "the open window kept the section")
end)

test("window settings: the outfit row's marks follow their rows, the name taking the EM mark's place", function()
    local NS, M = opened()
    local id = NS.Outfits.Create("Hero", { HeadSlot = { id = 0 } })
    NS.Outfits.Get(id).trigger = { id = "IN_DUNGEON" }
    NS.Window.MarkDirty(true); NS.Window.Render()
    local row = rowOf(NS, "outfit")
    assertTrue(row.em:IsShown()); assertTrue(row.trig:IsShown())
    assertEqual(leftX(row.name), 68)
    NS.SetByPath("window.marks.em", false)
    NS.SetByPath("window.marks.trigger", false)
    tick(M)
    row = rowOf(NS, "outfit")
    -- red under: RENDER.outfit showing the EM mark and the lightning whatever their rows say.
    assertFalse(row.em:IsShown(), "the EM mark stayed with its row off")
    assertFalse(row.trig:IsShown(), "the lightning stayed with its row off")
    assertEqual(leftX(row.name), 50, "the name did not move into the EM mark's place")
    NS.SetByPath("window.marks.em", true)
    NS.SetByPath("window.marks.trigger", true)
    tick(M)
    row = rowOf(NS, "outfit")
    assertTrue(row.em:IsShown()); assertTrue(row.trig:IsShown())
    assertEqual(leftX(row.name), 68)
end)
