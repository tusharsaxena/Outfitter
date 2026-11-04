-- tests/test_broker.lua — the Outfits data source (sheet and window feedback plan Task 3.8; design G9):
-- modules/Broker.lua's second LibDataBroker object, the old addon's outfit switcher. Its text and icon
-- follow the worn outfit; left-click opens the outfit menu through the real NS.OpenMenu seam (the
-- shared tests/dialog_scene.lua recorder), right-click toggles the window, and it is never put on the
-- minimap. The stood-down cases are tests/test_disabled.lua's.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dialog_scene.lua")(T)

local NAME = "OutfitterRebornOutfits"

local function object(M) return M.LibStub("LibDataBroker-1.1"):GetDataObjectByName(NAME) end

-- A label without its inline icon and color escapes.
local function plain(label)
    return (tostring(label):gsub("|T.-|t%s*", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function naked(NS)
    local items = {}
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do items[slot] = { id = 0 } end
    return items
end

-- A Complete outfit and two Accessory ones (one named to sort first), on a fresh scene.
local function outfits(NS)
    local O = NS.Outfits
    return {
        bare  = O.Create("Bare", naked(NS)),
        ride  = O.Create("Ride", { FeetSlot = { id = 0 } }),
        cloak = O.Create("Cloak", { BackSlot = { id = 0 } }),
    }
end

local function open(M, ctl)
    ctl.menus = {}
    object(M).OnClick(M.UIParent, "LeftButton")
    assertTrue(#ctl.menus > 0, "left-click opened no menu")
    return ctl.menus[#ctl.menus].rows
end

local function find(rows, text)
    for _, r in ipairs(rows) do
        if r.label and plain(r.label):find(text, 1, true) then return r end
    end
    return nil
end

-- A checked row: the menu's tick in front of the row's own icon, so two inline textures.
local function ticked(row)
    local _, n = row.label:gsub("|T", "")
    return n >= 2
end

test("broker: a data source named OutfitterRebornOutfits exists and is not on the minimap", function()
    local NS, M = scene()
    local obj = object(M)
    assertEqual(type(obj), "table", "no Outfits data source")
    assertEqual(obj.type, "data source")
    assertEqual(obj.label, NS.BRAND .. ": Outfits")
    assertEqual(NS.Broker.Object(), obj, "NS.Broker.Object answers the registered object")
    -- red under: a LibDBIcon:Register of the second object (the minimap keeps one button, launcher-§1).
    assertNil(M.LibStub("LibDBIcon-1.0").objects[NAME], "the Outfits object was put on the minimap")
    assertTrue(M.LibStub("LibDBIcon-1.0").objects.OutfitterReborn ~= nil, "the launcher's button is still there")
end)

test("broker: text and icon follow the worn outfit", function()
    local NS, M = scene()
    local ids = outfits(NS)
    local glyph = assert(NS.Icon("ph:sword"))
    assertTrue(NS.Outfits.SetIcon(ids.ride, glyph, "ff8000"))
    NS.Stack.Wear(ids.ride, { hw = true })
    M.__fireTimers()
    local obj = object(M)
    assertEqual(obj.text, "Ride")
    -- red under: a broker that never listens to the stack's messages (the text stays the brand).
    assertEqual(obj.icon, glyph)
    assertEqual(("%.2f %.2f %.2f"):format(obj.iconR, obj.iconG, obj.iconB), ("%.2f %.2f %.2f"):format(1, 128 / 255, 0))
    NS.Stack.Remove(ids.ride, { hw = true })
    M.__fireTimers()
    assertEqual(obj.text, NS.BRAND, "taking it off did not reach the text")
end)

test("broker: no outfit shows the brand and the coat hanger", function()
    local NS, M = scene()
    local obj = object(M)
    assertNil(NS.Stack.Top())
    assertEqual(obj.text, NS.BRAND)
    assertEqual(obj.icon, NS.Constants.DEFAULT_OUTFIT_ICON)
    -- The tinted hanger: the sheet button's own token, not the rows' white.
    local r, g, b = NS.SkinColor("of.sheet.button")
    assertEqual(("%.2f %.2f %.2f"):format(obj.iconR, obj.iconG, obj.iconB), ("%.2f %.2f %.2f"):format(r, g, b))
end)

test("broker: left-click lists categories then outfits, worn ones checked, missing in the missing color", function()
    local NS, M, ctl = scene()
    local ids = outfits(NS)
    local status = NS.Outfits.Status
    NS.Outfits.Status = function(id) if id == ids.cloak then return "missing" end return status(id) end
    NS.Stack.Wear(ids.ride, { hw = true })
    M.__fireTimers()
    local rows = open(M, ctl)
    local order = {}
    for _, r in ipairs(rows) do order[#order + 1] = r.divider and "-" or plain(r.label) end
    -- The checkbox rows carry the tick in front of a worn one, so the order is read without it.
    assertEqual(table.concat(order, "|"), NS.BRAND .. "|Open outfit window|Automatic changes|"
        .. "Complete outfits|Bare|Accessories|Cloak|Ride")
    assertTrue(rows[1].title, "the brand is a title")
    assertTrue(find(rows, "Complete outfits").title and find(rows, "Accessories").title, "categories are titles")
    -- Each outfit row is a toggle that keeps the menu open, drawn with its icon.
    for _, name in ipairs({ "Bare", "Cloak", "Ride" }) do
        local r = find(rows, name)
        assertTrue(r.keepOpen, name .. " is not a checkbox row")
        assertTrue(r.label:find("|T", 1, true) ~= nil, name .. " has no icon")
    end
    assertTrue(ticked(find(rows, "Ride")), "the worn outfit is not checked")
    assertFalse(ticked(find(rows, "Cloak")), "an outfit not worn is checked")
    -- red under: an outfit row drawn without the window's status color.
    assertTrue(find(rows, "Cloak").label:find(NS.SkinEscape("of.outfit.missing") .. "Cloak", 1, true) ~= nil,
        find(rows, "Cloak").label)
    -- Automatic changes is the `auto` verb's toggle.
    local auto = find(rows, "Automatic changes")
    assertTrue(auto.keepOpen)
    auto.onClick()
    assertFalse(NS.GetSetting("auto.enabled"), "Automatic changes did not turn auto off")
    auto.onClick()
    assertTrue(NS.GetSetting("auto.enabled") ~= false, "Automatic changes did not turn auto back on")
end)

-- The legacy menu listed only visible outfits (Outfitter.lua:2452 OutfitIsVisible at d396f11): not
-- Disabled and not hidden from the bar, the rule modules/Bar.lua's LiveSource keeps.
test("broker: the menu leaves out an outfit whose trigger is off or that is hidden from the bar", function()
    local NS, M, ctl = scene()
    local ids = outfits(NS)
    NS.SetByPath("outfit.bar.hide", true, ids.cloak)
    NS.SetByPath("outfit.trigger.id", "IN_DUNGEON", ids.ride)
    NS.SetByPath("outfit.trigger.disabled", true, ids.ride)
    M.__fireTimers()
    local order = {}
    for _, r in ipairs(open(M, ctl)) do order[#order + 1] = r.divider and "-" or plain(r.label) end
    -- red under: a menu that lists every outfit the window does (and an empty category's title).
    assertEqual(table.concat(order, "|"), NS.BRAND .. "|Open outfit window|Automatic changes|"
        .. "Complete outfits|Bare")
end)

test("broker: clicking a worn accessory removes it; clicking a Complete wears it", function()
    local NS, M, ctl = scene()
    local ids = outfits(NS)
    NS.Stack.Wear(ids.ride, { hw = true })
    M.__fireTimers()
    find(open(M, ctl), "Ride").onClick()
    M.__fireTimers()
    assertFalse(NS.Stack.IsWorn(ids.ride), "a worn accessory was not taken off")
    find(open(M, ctl), "Bare").onClick()
    M.__fireTimers()
    assertTrue(NS.Stack.IsWorn(ids.bare), "the Complete outfit was not worn")
    -- red under: toggling a worn Complete off (the legacy rule re-wears it).
    find(open(M, ctl), "Bare").onClick()
    M.__fireTimers()
    assertTrue(NS.Stack.IsWorn(ids.bare), "a worn Complete outfit was taken off")
    find(open(M, ctl), "Ride").onClick()
    M.__fireTimers()
    assertTrue(NS.Stack.IsWorn(ids.ride), "an accessory not worn was not put on")
end)

test("broker: a modifier-click asks to set current", function()
    local NS, M, ctl = scene()
    local ids = outfits(NS)
    local calls = {}
    local real = NS.Popups.ShowSetCurrent
    NS.Popups.ShowSetCurrent = function(id) calls[#calls + 1] = id; return real(id) end
    local row = find(open(M, ctl), "Ride")
    M.__modifiers.shift = true
    row.onClick()
    M.__modifiers.shift = false
    M.__fireTimers()
    assertEqual(#calls, 1, "no set-current prompt")
    assertEqual(calls[1], ids.ride)
    assertFalse(NS.Stack.IsWorn(ids.ride), "a modifier-click also wore the outfit")
end)

test("broker: right-click toggles the window", function()
    local NS, M = scene()
    local toggles = {}
    local real = NS.Dock.Toggle
    NS.Dock.Toggle = function(closeSheet) toggles[#toggles + 1] = closeSheet end
    object(M).OnClick(M.UIParent, "RightButton")
    NS.Dock.Toggle = real
    assertEqual(#toggles, 1, "right-click did not toggle the window")
    assertTrue(toggles[1], "the window toggle closes the sheet as the launcher's does")
end)

-- G9 lists the menu entry as *Open outfit window*: with the window already up it keeps it (and the
-- sheet) open, where the right-click is the toggle.
test("broker: the menu's Open outfit window opens, and never closes, the window", function()
    local NS, M, ctl = scene()
    local opens, toggles = 0, 0
    local realOpen, realToggle = NS.Dock.Open, NS.Dock.Toggle
    NS.Dock.Open = function() opens = opens + 1 end
    NS.Dock.Toggle = function() toggles = toggles + 1 end
    find(open(M, ctl), "Open outfit window").onClick()
    NS.Dock.Open, NS.Dock.Toggle = realOpen, realToggle
    -- red under: the entry sharing the right-click's NS.Dock.Toggle(true) (a second pick closes both).
    assertEqual(toggles, 0, "the menu entry toggled the window")
    assertEqual(opens, 1, "the menu entry did not open the window")
end)

-- A Complete outfit's wear takes every other outfit off the stack (modules/OutfitStack.lua), and the
-- menu stays open after a row's click: every row's tick is read again, not only the clicked one's.
test("broker: wearing a Complete outfit from the menu clears the ticks of the outfits it took off", function()
    local NS, M, ctl = scene()
    local ids = outfits(NS)
    local other = NS.Outfits.Create("Armor", naked(NS))
    NS.Stack.Wear(ids.bare, { hw = true })
    M.__fireTimers()
    local rows = open(M, ctl)
    assertTrue(ticked(find(rows, "Bare")), "the worn Complete outfit is not checked")
    find(rows, "Armor").onClick()
    M.__fireTimers()
    assertTrue(NS.Stack.IsWorn(other), "the clicked Complete outfit was not worn")
    assertFalse(NS.Stack.IsWorn(ids.bare), "the first Complete outfit is still worn")
    -- red under: a recorder that repaints only the clicked row (Bare keeps its stale tick).
    assertTrue(ticked(find(rows, "Armor")), "the clicked outfit is not checked")
    assertFalse(ticked(find(rows, "Bare")), "the outfit taken off is still checked")
end)

test("broker: a modifier-click closes the menu before the set-current prompt", function()
    local NS, M, ctl = scene()
    outfits(NS)
    local closed = 0
    local realClose = NS.CloseMenu
    NS.CloseMenu = function(...) closed = closed + 1; return realClose(...) end
    local row = find(open(M, ctl), "Ride")
    M.__modifiers.shift = true
    row.onClick()
    M.__modifiers.shift = false
    NS.CloseMenu = realClose
    -- red under: the prompt opening under a menu that stays open.
    assertTrue(closed > 0, "the menu stayed open over the set-current prompt")
end)

test("broker: the tooltip names the brand, the current outfit and both clicks", function()
    local NS, M = scene()
    local ids = outfits(NS)
    NS.Stack.Wear(ids.ride, { hw = true })
    M.__fireTimers()
    local lines = {}
    object(M).OnTooltipShow({ AddLine = function(_, text) lines[#lines + 1] = text end })
    assertEqual(table.concat(lines, "|"), NS.BRAND .. "|Current outfit: Ride|Left-click: choose an outfit|"
        .. "Right-click: outfit window")
end)

-- One click on an Accessory outfit in combat, through `click(NS, M, id)`, on a fresh scene: whether it
-- is worn after, and what it printed.
local function inCombat(click)
    local NS, M, ctl = scene()
    local ids = outfits(NS)
    M.__resetPrinted()
    M.__world:setCombat(true)
    local ok, err = pcall(click, NS, M, ctl, ids.ride)
    assertTrue(ok, tostring(err))
    M.__fireTimers()
    return NS.Stack.IsWorn(ids.ride), table.concat(M.__printed(), "\n")
end

test("broker: in combat a wear is queued or refused as the window's is", function()
    local wornB, printedB = inCombat(function(_, M, ctl) find(open(M, ctl), "Ride").onClick() end)
    local wornW, printedW = inCombat(function(NS, _, _, id)
        NS.WindowRows.OnClick({ entry = { kind = "outfit", id = id } }, "LeftButton")
    end)
    -- red under: a broker that refuses in combat on its own (the window queues the wear).
    assertEqual(wornB, wornW, "the broker's combat wear differs from the window's")
    assertEqual(printedB, printedW)
end)
