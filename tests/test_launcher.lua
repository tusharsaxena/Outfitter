-- tests/test_launcher.lua — the launcher descriptor (one LDB object, registered twice), its static
-- icon and label, the library's right-click menu onto the shared handlers, the status tooltip's one
-- host line and the Minimap button row (launcher-§1/§2/§3, design §4.5). The key bindings are
-- tests/test_keybinds.lua's. P3 C13 pins the scaffold; P4.24 adds the host line for empty, temp and
-- named stacks and the icon held static across outfit changes (design §9.3).

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function broker(inst)
    return inst.mocks.LibStub("LibDataBroker-1.1"):GetDataObjectByName("OutfitterReborn")
end

--- The client's MenuUtil, recorded for one right-click and taken away after it: the mock carries no
--- MenuUtil of its own, because the degraded context-menu case (tests/test_surface_parity.lua) needs
--- a client without one. A checkbox's tick is asked live, as the client asks it.
local function openMenu(inst)
    local M = inst.mocks
    local menu = { titles = {}, entries = {} }
    local function entry(text, isSelected, onClick)
        local e = { text = text, isSelected = isSelected or function() return false end,
                    click = onClick, enabled = true }
        menu.entries[#menu.entries + 1] = e
        return { SetEnabled = function(_, on) e.enabled = on and true or false end }
    end
    local root = {
        CreateTitle    = function(_, text) menu.titles[#menu.titles + 1] = text end,
        CreateDivider  = function() end,
        CreateCheckbox = function(_, text, isSelected, onClick) return entry(text, isSelected, onClick) end,
        CreateButton   = function(_, text, onClick) return entry(text, nil, onClick) end,
    }
    function menu:Find(prefix)
        for _, e in ipairs(self.entries) do
            if e.text:sub(1, #prefix) == prefix then return e end
        end
    end
    function menu:Click(prefix)
        local e = assert(self:Find(prefix), "no menu entry " .. prefix)
        if e.enabled then return e.click() end
    end
    M.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    local ok, err = pcall(broker(inst).OnClick, M.UIParent, "RightButton")
    M.MenuUtil = nil
    assert(ok, err)
    return menu
end

--- The status tooltip's lines, drawn into a recording tooltip.
local function tooltipLines(inst)
    local lines = {}
    broker(inst).OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = text end })
    return lines
end

local function hasLine(lines, needle)
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then return true end
    end
    return false
end

test("launcher: one object named for the folder, labeled with the brand, wearing the logo", function()
    local inst = T.load()
    local obj = broker(inst)
    assertEqual(type(obj), "table")
    assertEqual(obj.type, "launcher")
    assertEqual(obj.label, "Ka0s Outfitter Reborn")
    assertEqual(obj.label, inst.NS.BRAND, "the label is the brand constant, never L")
    assertEqual(obj.icon, "Interface\\AddOns\\OutfitterReborn\\media\\logos\\outfitterreborn.logo.128.tga")
    local icon = inst.mocks.LibStub("LibDBIcon-1.0")
    assertEqual(icon.objects.OutfitterReborn.broker, obj, "the minimap button is the SAME object")
    assertEqual(icon.objects.OutfitterReborn.db, inst.NS.db.global.minimap, "LibDBIcon shares the stored table")
    assertTrue(inst.NS.Launcher:IsRegistered())
end)

test("launcher: left-click opens the settings panel, in either state", function()
    local inst = T.load()
    local opened = 0
    inst.NS.OpenOptionsPanel = function() opened = opened + 1 end
    broker(inst).OnClick(inst.mocks.UIParent, "LeftButton")
    assertEqual(opened, 1)
    inst.NS.SetByPath("enabled", false)
    broker(inst).OnClick(inst.mocks.UIParent, "LeftButton")
    assertEqual(opened, 2, "a disabled addon is re-enabled from the panel")
end)

test("launcher: right-click lists the library menu, with no Sim row", function()
    local inst = T.load()
    local menu = openMenu(inst)
    local labels = {}
    for i, e in ipairs(menu.entries) do labels[i] = e.text end
    assertEqual(table.concat(labels, "|"), "Enabled|Locked|Test mode|Show window|Open settings|Open skin selector")
    assertEqual(menu.titles[1], "Ka0s Outfitter Reborn")
end)

test("launcher: each menu entry runs the shared handler", function()
    local inst = T.load()
    local NS = inst.NS
    openMenu(inst):Click("Locked")
    assertEqual(NS.db.profile.locked, true)
    assertTrue(openMenu(inst):Find("Locked").isSelected(), "the tick follows the setting")
    openMenu(inst):Click("Locked")
    assertEqual(NS.db.profile.locked, false)

    -- Show window is the Show window key's handler: it toggles the outfit window (P4.19).
    -- red under: a toggleWindow that still opens the settings panel.
    local toggled, settings, closeSheet = 0, 0, nil
    NS.Dock.Toggle = function(c) toggled = toggled + 1; closeSheet = c end
    NS.OpenOptionsPanel = function() settings = settings + 1 end
    openMenu(inst):Click("Show window")
    assertEqual(toggled, 1)
    -- red under: toggleWindow calling NS.Dock.Toggle() (the legacy ToggleUI(true) closed the sheet too).
    assertEqual(closeSheet, true, "the launcher's close takes the sheet with it")
    assertEqual(settings, 0, "Show window opened the settings panel")
    assertFalse(openMenu(inst):Find("Show window").isSelected(), "the outfit window is not shown")
    assertFalse(openMenu(inst):Find("Test mode").isSelected(), "test mode is off with no preview")
    openMenu(inst):Click("Test mode")                      -- no preview yet: nothing to toggle, no raise

    openMenu(inst):Click("Enabled")
    assertEqual(NS.db.profile.enabled, false)
    assertTrue(NS.IsDisabled())
end)

test("launcher: while disabled every entry but Enabled and Open settings is grayed", function()
    local inst = T.load()
    inst.NS.SetByPath("enabled", false)
    local menu = openMenu(inst)
    assertTrue(menu:Find("Enabled").enabled)
    assertTrue(menu:Find("Open settings").enabled)
    for _, label in ipairs({ "Locked", "Test mode", "Show window", "Open skin selector" }) do
        assertFalse(menu:Find(label).enabled, label .. " is not grayed")
    end
    menu:Click("Enabled")
    assertFalse(inst.NS.IsDisabled(), "Enabled works in the off state")
end)

test("launcher: the tooltip's host line is the stack's label, absent without a stack", function()
    -- red under: an onTooltipShow that reads NS.Stack unguarded. It raises inside the library's
    -- pcall and every other line still draws, so only the library's debug line says so.
    local inst = T.load()
    local realStack = inst.NS.Stack
    inst.NS.Stack = nil
    local logged = {}
    local realDebug = inst.NS.Debug
    inst.NS.Debug = function(tag, fmt, ...) logged[#logged + 1] = tostring(tag) .. ": " .. fmt:format(...) end
    local lines = tooltipLines(inst)
    inst.NS.Debug = realDebug
    assertFalse(hasLine(lines, "Current outfit:"), "a host line with no stack")
    assertFalse(hasLine(logged, "raised"), "the host line raised: " .. tostring(logged[1]))
    assertTrue(hasLine(lines, "Ka0s Outfitter Reborn  v1.1.0"), "the title: " .. tostring(lines[1]))
    inst.NS.Stack = { CurrentLabel = function() return "Fishing" end }
    lines = tooltipLines(inst)
    assertTrue(hasLine(lines, "Current outfit: Fishing"), "the host line")
    inst.NS.Stack = realStack
    lines = tooltipLines(inst)
    assertTrue(hasLine(lines, "Current outfit: None"), "the real stack's label for an empty stack (P4.9)")
end)

test("launcher: the Minimap button row hides and shows the real button", function()
    local inst = T.load()
    local NS, icon = inst.NS, inst.mocks.LibStub("LibDBIcon-1.0")
    NS.SetByPath(NS.MINIMAP_PATH, false)
    assertEqual(icon.__shown.OutfitterReborn, false)
    assertEqual(NS.db.global.minimap.hide, true, "the row writes LibDBIcon's own key")
    assertFalse(NS.GetSetting(NS.MINIMAP_PATH))
    NS.SetByPath(NS.MINIMAP_PATH, true)
    assertEqual(icon.__shown.OutfitterReborn, true)
    assertEqual(NS.db.global.minimap.hide, false)
    assertTrue(NS.GetSetting(NS.MINIMAP_PATH))
end)

test("launcher: no compartment function and no compartment TOC line (H6)", function()
    local f = assert(io.open(T.root .. "/OutfitterReborn.toc", "rb"))
    local toc = f:read("*a")
    f:close()
    assertEqual(toc:find("AddonCompartment", 1, true), nil, "a compartment TOC line")
    for name in pairs(T.mocks._G) do
        assertFalse(type(name) == "string" and name:find("Compartment", 1, true) ~= nil,
            "a compartment global: " .. tostring(name))
    end
end)

test("launcher: library-absent, no button, said once, and the row still writes the stored key", function()
    local bare = T.load{ libFiles = {}, init = false }
    bare.mocks.__resetPrinted()
    assertFalse(bare.NS.Launcher:Register())
    assertFalse(bare.NS.Launcher:Register())
    local said = 0
    for _, l in ipairs(bare.mocks.__printed()) do
        if l:find("no minimap button", 1, true) then said = said + 1 end
    end
    assertEqual(said, 1, "the launcher's missing line is said once")

    local inst = T.load{ libFiles = {} }
    local NS = inst.NS
    assertFalse(NS.Launcher:IsRegistered())
    assertEqual(NS.Launcher:Object(), nil)
    NS.Launcher:SetShown(false)
    assertEqual(NS.db.global.minimap.hide, true)
    assertFalse(NS.Launcher:IsShown())
end)
