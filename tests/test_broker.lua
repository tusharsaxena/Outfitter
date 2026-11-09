-- tests/test_broker.lua — the Outfits data source (sheet and window feedback plan Task 3.8; design G9):
-- modules/Broker.lua's second LibDataBroker object, the old addon's outfit switcher. Its text and icon
-- follow the worn outfit; hovering opens the outfit menu under it through the real NS.OpenMenu seam
-- (the shared tests/dialog_scene.lua recorder), left-click opens the character sheet with the window,
-- right-click the settings (Forever smoke feedback 3), and it is never put on the minimap. The
-- stood-down cases are tests/test_disabled.lua's.

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
    object(M).OnEnter(M.UIParent)
    assertTrue(#ctl.menus > 0, "hovering opened no menu")
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
    assertNil(obj.iconCoords, "a glyph is drawn whole, never cropped")
    NS.Stack.Remove(ids.ride, { hw = true })
    M.__fireTimers()
    assertEqual(obj.text, NS.BRAND, "taking it off did not reach the text")
end)

test("broker: no outfit shows the brand and the default icon, untinted and cropped", function()
    local NS, M = scene()
    local obj = object(M)
    assertNil(NS.Stack.Top())
    assertEqual(obj.text, NS.BRAND)
    -- Smoke round 2 design G1 (D1): 132724, white, cropped like the window's art.
    -- red under: the gold-tinted coat hanger (the retired of.sheet.button token).
    assertEqual(obj.icon, 132724)
    assertEqual(("%.2f %.2f %.2f"):format(obj.iconR, obj.iconG, obj.iconB), "1.00 1.00 1.00")
    local c = obj.iconCoords
    assertTrue(type(c) == "table" and c[1] == 0.07 and c[2] == 0.93 and c[3] == 0.07 and c[4] == 0.93,
        "the idle icon is not cropped")
end)

test("broker: the hover menu lists categories then outfits, worn ones checked, missing in the missing color", function()
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
        .. "Complete outfits|Bare|Accessories|Cloak|Ride|Left-click: outfit window|Right-click: settings")
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
        .. "Complete outfits|Bare|Left-click: outfit window|Right-click: settings")
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

test("broker: left-click opens the sheet with the window; right-click opens the settings", function()
    local NS, M, ctl = scene()
    local opens, settings = 0, 0
    local realOpen, realSettings = NS.Dock.Open, NS.OpenOptionsPanel
    NS.Dock.Open = function() opens = opens + 1 end
    NS.OpenOptionsPanel = function() settings = settings + 1 end
    ctl.menus = {}
    object(M).OnClick(M.UIParent, "LeftButton")
    -- red under: the 2026-11-08 left-click (the outfit menu).
    assertEqual(opens, 1, "left-click did not open the window")
    assertEqual(#ctl.menus, 0, "left-click still opens the menu")
    object(M).OnClick(M.UIParent, "RightButton")
    NS.Dock.Open, NS.OpenOptionsPanel = realOpen, realSettings
    -- red under: the 2026-11-08 right-click (the window toggle).
    assertEqual(settings, 1, "right-click did not open the settings")
    assertEqual(opens, 1, "right-click touched the window")
end)

test("broker: the hover menu drops under the object and closes once the pointer has left both", function()
    local NS, M, ctl = scene()
    local W = M.LibStub("LibKa0s-Widgets-1.0")
    local record = W.ContextMenu
    local menu = { shown = true, over = false }
    function menu:IsShown() return self.shown end
    function menu:IsMouseOver() return self.over end
    W.ContextMenu = function(...) record(...); return menu end
    local anchor = M.CreateFrame("Button", nil, M.UIParent)
    local inside = true
    rawset(anchor, "IsMouseOver", function() return inside end)
    local closes = 0
    local realClose = NS.CloseMenu
    NS.CloseMenu = function(...) closes = closes + 1; menu.shown = false; return realClose(...) end
    ctl.menus = {}
    object(M).OnEnter(anchor)
    assertEqual(#ctl.menus, 1)
    assertFalse(ctl.menus[1].opts.cursor, "the hover menu drops under the object, not at the pointer")
    object(M).OnEnter(anchor)
    assertEqual(#ctl.menus, 1, "a second enter while it is up opens no second menu")
    local watcher
    for _, f in ipairs(M.__shownFrames()) do
        if f.__scripts and f.__scripts.OnUpdate and f.__parent == M.UIParent and not f.__name then watcher = f end
    end
    assertTrue(watcher ~= nil, "a watcher runs while the hover menu is up")
    inside = false
    menu.over = true
    watcher:__fire("OnUpdate", 1)
    assertEqual(closes, 0, "the pointer on the menu keeps it")
    menu.over = false
    watcher:__fire("OnUpdate", 0.1)
    assertEqual(closes, 0, "closed before the grace")
    watcher:__fire("OnUpdate", 0.3)
    NS.CloseMenu = realClose
    -- red under: no watcher (the hover menu would stay up after the pointer left).
    assertEqual(closes, 1, "the menu stayed up off the object and the menu")
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

test("broker: the hover menu ends with both click hints, and there is no tooltip", function()
    local NS, M, ctl = scene()
    outfits(NS)
    local rows = open(M, ctl)
    assertEqual(plain(rows[#rows - 1].label), "Left-click: outfit window")
    assertEqual(plain(rows[#rows].label), "Right-click: settings")
    -- red under: OnTooltipShow kept (a broker display prefers OnEnter, but some draw both).
    assertNil(object(M).OnTooltipShow)
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
