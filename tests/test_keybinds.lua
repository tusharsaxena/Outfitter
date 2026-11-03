-- tests/test_keybinds.lua — the key bindings as the player meets them (launcher-§6, options-ui-§20,
-- design §4.4): Bindings.xml in the addon's own category, NS.BINDINGS in file order with its labels,
-- the hidden non-secure buttons and their press, and the General page's last tab, `Keybindings`,
-- drawn by the library. P3 C13 pinned the first row, Show window; P4.24 the other 13 (the ten wear
-- keys with their anti-panic and announce rules, AutoOn, AutoOff, UpdateOutfit) on the real modules.
-- Capture, conflict and settings-window cases are the library's (testing-§8) and are not repeated.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SHOW = "CLICK OutfitterRebornToggleWindow:LeftButton"
local function wearKey(n) return "CLICK OutfitterRebornWearOutfit" .. n .. ":LeftButton" end
local AUTO_ON = "CLICK OutfitterRebornAutoOn:LeftButton"
local AUTO_OFF = "CLICK OutfitterRebornAutoOff:LeftButton"
local UPDATE = "CLICK OutfitterRebornUpdateOutfit:LeftButton"
local COMMANDS = { SHOW }
local LABELS = {
    [SHOW] = "Toggle outfit window",
    [AUTO_ON] = "Turn on automatic outfit changes",
    [AUTO_OFF] = "Turn off automatic outfit changes",
    [UPDATE] = "Update outfit to equipped items",
}
for n = 1, 10 do
    COMMANDS[#COMMANDS + 1] = wearKey(n)
    LABELS[wearKey(n)] = "Wear outfit " .. n
end
COMMANDS[#COMMANDS + 1] = AUTO_ON
COMMANDS[#COMMANDS + 1] = AUTO_OFF
COMMANDS[#COMMANDS + 1] = UPDATE

local ctxOf = setmetatable({}, { __mode = "k" })   -- panel -> the ctx its renderer was handed

--- Show the General page and draw it on `tab` (nil: its first), answering the strip's tab keys, the
--- Keybindings tab's row records when that tab drew, and the page's ctx.
local function showGeneral(M, NS, tab)
    local H = NS.Helpers
    local realTabs, realRows = H.RenderTabbedSchema, H.KeybindRows
    local keys, rows, ctx
    H.RenderTabbedSchema = function(c, ...)
        ctx = c
        local groups, drawn = realTabs(c, ...)
        keys = drawn
        return groups, drawn
    end
    H.KeybindRows = function(...)
        rows = realRows(...)
        return rows
    end
    local panel = M.__subcategories["General"]
    local ok, err = pcall(function()
        panel:Show()
        panel:__fire("OnShow")
        -- An already-drawn page is not redrawn on a show; draw it again, on the tab asked for.
        ctx = ctx or ctxOf[panel]
        if ctx then
            ctxOf[panel] = ctx
            ctx.activeTab = tab
            ctx._renderFn(ctx)
        end
    end)
    H.RenderTabbedSchema, H.KeybindRows = realTabs, realRows
    assert(ok, err)
    return keys, rows, ctx
end

local function anyLine(M, needle)
    for _, l in ipairs(M.__printed()) do
        if l:find(needle, 1, true) then return true end
    end
    return false
end

test("keybinds: NS.BINDINGS is Bindings.xml's order, Show window first, each with a tooltip", function()
    local NS = T.NS
    assertEqual(#NS.BINDINGS, #COMMANDS)
    for i, command in ipairs(COMMANDS) do
        assertEqual(NS.BINDINGS[i].command, command)
        assertEqual(type(NS.BINDINGS[i].tooltip), "string", command)
        assertTrue(#NS.BINDINGS[i].tooltip > 0, command .. " tooltip is empty")
    end
end)

test("keybinds: Bindings.xml is the addon's own category, no header, no default, labeled", function()
    local list = T.assertBindingsXml(T.root .. "/Bindings.xml", {
        category = "BINDING_HEADER_OUTFITTERREBORN",
        commands = T.NS.BINDINGS,
        brand    = T.NS.BRAND,
        globals  = T.mocks._G,
        labels   = LABELS,
    })
    assertEqual(#list, #COMMANDS)
end)

test("keybinds: the category's title is the brand constant, never a locale string", function()
    -- launcher-§1, anti-patterns #84: an overlay that translates the brand key leaves the header alone.
    -- Assigned at file scope: an instance that never initializes has it already.
    local inst = T.load{ init = false }
    assertEqual(inst.mocks._G.BINDING_HEADER_OUTFITTERREBORN, "Ka0s Outfitter Reborn")
    assertEqual(inst.mocks._G.BINDING_HEADER_OUTFITTERREBORN, inst.NS.BRAND)
    local f = assert(io.open(T.root .. "/core/LauncherSetup.lua", "rb"))
    local src = f:read("*a")
    f:close()
    assertTrue(src:find('rawset(_G, "BINDING_HEADER_OUTFITTERREBORN", NS.BRAND)', 1, true) ~= nil,
        "the header is not written from NS.BRAND")
end)

test("keybinds: each button is plain, named, hidden and registered for the down edge", function()
    -- The press toggles once: a button registered for both edges would toggle twice per key.
    local clicks = {}
    local inst = T.load{ mutate = function(M)
        local create = M.CreateFrame
        M.CreateFrame = function(...)
            local f = create(...)
            local name = select(2, ...)
            if type(name) == "string" then
                f.RegisterForClicks = function(_, ...) clicks[name] = table.concat({ ... }, ",") end
            end
            return f
        end
    end }
    local env = inst.mocks._G
    for _, command in ipairs(COMMANDS) do
        local name = command:match("^CLICK (.-):LeftButton$")
        local b = env[name]
        assertEqual(type(b), "table", name)
        assertEqual(b.__frameType, "Button", name)
        assertFalse(b:IsShown(), name .. " is shown")
        assertEqual(b.__template, nil, name .. " uses a template (a secure one adds combat rules)")
        assertEqual(clicks[name], "AnyDown", name)
        assertEqual(env["BINDING_NAME_" .. command], LABELS[command])
    end
end)

test("keybinds: the Show window press runs the launcher's Show window handler", function()
    local inst = T.load()
    local opened = 0
    inst.NS.Dock.Toggle = function() opened = opened + 1 end
    inst.mocks._G.OutfitterRebornToggleWindow:__fire("OnClick", "LeftButton", true)
    assertEqual(opened, 1, "the press did not reach the handler (NS.Dock.Toggle)")
end)

test("keybinds: a press while stood down refuses through the one helper, with the verb's line", function()
    -- red under: an OnClick that calls the handler first, or one that refuses silently (launcher-§6,
    -- "a press that is silent where the verb would print is a finding").
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    local opened = 0
    NS.Dock.Toggle = function() opened = opened + 1 end
    NS.SetByPath("enabled", false)
    M.__resetPrinted()
    M._G.OutfitterRebornToggleWindow:__fire("OnClick", "LeftButton", true)
    assertEqual(opened, 0, "the press ran its handler while disabled")
    assertTrue(anyLine(M, "is disabled"), "no disabled line: " .. tostring(M.__printed()[1]))
    assertTrue(anyLine(M, NS.SLASH .. " enable"), "the line names the enable verb")

    NS.SetByPath("enabled", true)
    NS.lifecycle:Hold(NS.HOLD_PERF)
    M.__resetPrinted()
    M._G.OutfitterRebornToggleWindow:__fire("OnClick", "LeftButton", true)
    NS.lifecycle:Release(NS.HOLD_PERF)
    assertEqual(opened, 0, "the press ran its handler under the perf hold")
    assertTrue(anyLine(M, "Not available during a performance capture."), "no perf line")
    assertFalse(anyLine(M, "is disabled"), "the disabled line under the perf hold alone")
end)

test("keybinds: the General page ends in the Keybindings tab, after Master controls", function()
    local M, NS = T.mocks, T.NS
    M.__resetPrinted()
    local keys = assert(showGeneral(M, NS, nil), "the General page drew no tab strip")
    assertEqual(keys[1], NS.Helpers.MASTER_GROUP, "Master controls stays first")
    assertEqual(keys[#keys], "Keybindings", "the Keybindings tab is the last")
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
end)

test("keybinds: the tab's rows are NS.BINDINGS in order, labeled as the client labels them", function()
    local M, NS = T.mocks, T.NS
    M.__resetPrinted()
    local _, rows = showGeneral(M, NS, "Keybindings")
    rows = assert(rows, "the Keybindings tab drew no rows")
    assertEqual(#rows, #NS.BINDINGS)
    for i, row in ipairs(rows) do
        assertEqual(row.command, NS.BINDINGS[i].command)
        assertEqual(row.label:GetText(), M._G["BINDING_NAME_" .. row.command])
        assertEqual(row.label:GetText(), LABELS[row.command])
    end
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
    showGeneral(M, NS, nil)
end)

test("keybinds: a key bound in the tab is the client's key; one set on the client's page shows", function()
    local M, NS = T.mocks, T.NS
    M.clearBindings()
    local _, rows = showGeneral(M, NS, "Keybindings")
    rows = assert(rows, "the Keybindings tab drew no rows")
    assertEqual(T.keybindThroughTab(rows[1], 1, "K", { shift = true }), M.KEY_BOUND)
    assertEqual(M.GetBindingKey(SHOW), "SHIFT-K")
    assertEqual(M.__savedBindingSets[#M.__savedBindingSets], M.GetCurrentBindingSet(), "saved to the set in force")

    -- One key, one action: binding SHIFT-K again moves nothing, and a second key keeps the first.
    assertTrue(M.SetBinding("F7", SHOW))
    while M.__fireTimers() > 0 do end
    assertEqual(M.GetBindingAction("SHIFT-K"), SHOW)
    assertEqual(M.GetBindingAction("F7"), SHOW)
    M.clearBindings()
    showGeneral(M, NS, nil)
end)

test("keybinds: in combat the tab binds nothing", function()
    local M, NS = T.mocks, T.NS
    M.clearBindings()
    local _, rows = showGeneral(M, NS, "Keybindings")
    rows = assert(rows, "the Keybindings tab drew no rows")
    local real = M.InCombatLockdown
    M.InCombatLockdown = function() return true end
    local ok, err = pcall(T.keybindThroughTab, rows[1], 1, "J")
    M.InCombatLockdown = real
    assert(ok, err)
    assertEqual(M.GetBindingKey(SHOW), nil, "a key was bound in combat")
    assertEqual(#M.__bindingWrites, 0, "a binding API write ran in combat")
    assertEqual(rows[1].status:GetText(), M.LibStub("LibKa0s-Options-1.0").KEYBIND_STRINGS.COMBAT)
    showGeneral(M, NS, nil)
end)

test("keybinds: the General Defaults tooltip says it leaves key bindings alone", function()
    local tip = T.mocks.__subcategories["General"].defaultsTooltip
    assertEqual(type(tip), "string", "no Defaults tooltip on the General page")
    assertTrue(tip:find(T.NS.Helpers.KEYBINDS_UNCHANGED, 1, true) ~= nil, tip)
end)

-- ── the wear, automation and update keys (P4.24, design §4.4) ────────────────────────────────────

--- A fresh instance at t = 100 on the geared scenario, PlayerState, Inventory and Equip resumed and
--- the first scan settled; every module is the real one.
local function scene()
    local inst = T.load({ mutate = function(M) M.__gear:load("geared") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    M.__fireTimers()
    NS.Inventory.Sync()
    M.__resetPrinted()
    return NS, M
end

local function press(M, command)
    local name = command:match("^CLICK (.-):LeftButton$")
    M._G[name]:__fire("OnClick", "LeftButton", true)
end

--- Every worn slot as an outfit stores it: a Complete outfit.
local function wornItems(NS)
    local items = {}
    for _, s in ipairs(NS.ItemData.SLOT_NAMES) do
        local info = NS.ItemInfo.FromSlot(s)
        items[s] = info and NS.ItemInfo.Snapshot(info) or { id = 0 }
    end
    return items
end

local function messages(M)
    local out = {}
    for i, m in ipairs(M.UIErrorsFrame.__messages) do out[i] = m.text end
    return table.concat(out, "|")
end

test("keybinds: Wear outfit 1 is assigned through the tab like any other row", function()
    local M, NS = T.mocks, T.NS
    M.clearBindings()
    local _, rows = showGeneral(M, NS, "Keybindings")
    rows = assert(rows, "the Keybindings tab drew no rows")
    assertEqual(rows[2].command, wearKey(1))
    assertEqual(T.keybindThroughTab(rows[2], 1, "1", { shift = true }), M.KEY_BOUND)
    assertEqual(M.GetBindingKey(wearKey(1)), "SHIFT-1")
    M.clearBindings()
    showGeneral(M, NS, nil)
end)

test("keybinds: a wear key wears a Complete outfit now and toggles any other, anti-panic 0.75 s", function()
    -- red under: a WearBoundOutfit that prints on the ignored repeat
    local NS, M = scene()
    local O, St = NS.Outfits, NS.Stack
    local normal = O.Create("Everyday", wornItems(NS))
    local hat = O.Create("Hat", { HeadSlot = { id = 0 } })
    O.SetBinding(normal, 1)
    O.SetBinding(hat, 2)
    press(M, wearKey(1))
    assertTrue(St.IsWorn(normal))
    assertEqual(NS.Equip.Pending(), false, "a key wear updates now")
    M.__now = 102
    press(M, wearKey(2))
    assertTrue(St.IsWorn(hat))
    M.__now = 102.5
    press(M, wearKey(2))
    assertTrue(St.IsWorn(hat), "a repeat within 0.75 s toggled")
    M.__now = 103.0                     -- 0.5 s after the ignored press: its clock refreshed
    press(M, wearKey(2))
    assertTrue(St.IsWorn(hat), "the window did not refresh on the ignored press")
    M.__now = 104
    press(M, wearKey(2))
    assertFalse(St.IsWorn(hat), "a press after the window toggles off")
    M.__now = 106
    press(M, wearKey(1))
    assertTrue(St.IsWorn(normal), "a Complete outfit's key re-wears, never toggles off")
    assertEqual(#M.__printed(), 0, "a key press printed: " .. tostring(M.__printed()[1]))
end)

test("keybinds: the press clears trigger.disabled and is a hardware event (a title is set)", function()
    local NS, M = scene()
    local O = NS.Outfits
    local hat = O.Create("Hat", { HeadSlot = { id = 0 } })
    O.Get(hat).trigger = { id = "FISHING", disabled = true }
    O.SetFlag(hat, "titleID", 3)
    O.SetBinding(hat, 4)
    press(M, wearKey(4))
    assertTrue(NS.Stack.IsWorn(hat))
    assertFalse(O.Get(hat).trigger.disabled == true, "the key did not clear Disabled")
    assertEqual(M.__world.currentTitle, 3, "the press wore without hw")
end)

test("keybinds: an unbound key says so", function()
    -- red under: a WearBoundOutfit that returns silently for an unbound key
    local NS, M = scene()
    press(M, wearKey(5))
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[OR%]|r ", "")) end
    assertEqual(table.concat(out, "|"), "No outfit is bound to key 5.")
    assertTrue(NS ~= nil)
end)

test("keybinds: the key announces on UIErrorsFrame in the outfit color, unless announceKeys is off", function()
    -- red under: an announce that ignores equip.announceKeys
    local NS, M = scene()
    local O = NS.Outfits
    local hat = O.Create("Hat", { HeadSlot = { id = 0 } })
    O.SetBinding(hat, 3)
    press(M, wearKey(3))
    M.__now = 102
    press(M, wearKey(3))
    assertEqual(messages(M), "Hat equipped|Hat unequipped")
    local c, m = NS.Constants.OUTFIT_MESSAGE_COLOR, M.UIErrorsFrame.__messages[1]
    assertEqual(m.r, c.r); assertEqual(m.g, c.g); assertEqual(m.b, c.b)
    assertEqual(c.r .. "," .. c.g .. "," .. c.b, "0.2,0.75,0.3")
    assertTrue(NS.SetByPath("equip.announceKeys", false))
    M.__now = 104
    press(M, wearKey(3))
    assertTrue(NS.Stack.IsWorn(hat))
    assertEqual(#M.UIErrorsFrame.__messages, 2, "announced with announceKeys off")
end)

test("keybinds: AutoOn and AutoOff write auto.enabled through the auto verb", function()
    local NS, M = scene()
    local verbs = {}
    local run = NS.RunVerb
    NS.RunVerb = function(verb, rest)
        verbs[#verbs + 1] = verb .. " " .. tostring(rest)
        return run(verb, rest)
    end
    press(M, AUTO_OFF)
    assertEqual(NS.GetSetting("auto.enabled"), false)
    press(M, AUTO_ON)
    assertEqual(NS.GetSetting("auto.enabled"), true)
    assertEqual(table.concat(verbs, ","), "auto off,auto on")
end)

test("keybinds: UpdateOutfit with no Complete outfit prints the line and raises nothing", function()
    local NS, M = scene()
    press(M, UPDATE)
    local out = {}
    for i, l in ipairs(M.__printed()) do out[i] = (l:gsub("^|cff00ffff%[OR%]|r ", "")) end
    assertEqual(table.concat(out, "|"), "No Complete outfit is equipped.")
    local normal = NS.Outfits.Create("Everyday", wornItems(NS))
    NS.Stack.Wear(normal, { now = true })
    M.__resetPrinted()
    press(M, UPDATE)
    assertTrue(anyLine(M, "Updated the outfit 'Everyday'"), "the key did not update the Complete outfit")
end)

test("keybinds: every button refuses through the one helper before its handler, AutoOn/AutoOff too", function()
    -- red under: an OnClick that runs the handler before NS.StoodDownRefusal()
    local NS, M = scene()
    local ran = {}
    NS.WearBoundOutfit = function(n) ran[#ran + 1] = "wear" .. n end
    NS.RunVerb = function(verb) ran[#ran + 1] = verb end
    NS.Dock.Toggle = function() ran[#ran + 1] = "toggle" end
    for _, hold in ipairs({ "disabled", "perf" }) do
        if hold == "disabled" then NS.SetByPath("enabled", false) else NS.lifecycle:Hold(NS.HOLD_PERF) end
        local refusal = NS.StoodDownRefusal()
        for _, command in ipairs(COMMANDS) do
            M.__resetPrinted()
            press(M, command)
            assertEqual(#M.__printed(), 1, command .. " under " .. hold)
            assertTrue(M.__printed()[1]:find(refusal, 1, true) ~= nil, command .. " under " .. hold)
        end
        if hold == "disabled" then NS.SetByPath("enabled", true) else NS.lifecycle:Release(NS.HOLD_PERF) end
    end
    assertEqual(table.concat(ran, ","), "", "a handler ran while stood down")
    assertEqual(NS.GetSetting("auto.enabled"), true, "a press wrote auto.enabled while stood down")
end)

test("keybinds: NS.WearBoundOutfit refuses for a direct caller too", function()
    local NS, M = scene()
    local hat = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    NS.Outfits.SetBinding(hat, 1)
    NS.SetByPath("enabled", false)
    M.__resetPrinted()
    NS.WearBoundOutfit(1)
    assertFalse(NS.Stack.IsWorn(hat), "the handler wore while disabled")
    assertTrue(anyLine(M, "is disabled"))
end)

test("keybinds: one key per outfit: binding a key to a second outfit takes it off the first", function()
    local NS = scene()
    local O = NS.Outfits
    local a = O.Create("A", { HeadSlot = { id = 0 } })
    local b = O.Create("B", { HeadSlot = { id = 0 } })
    O.SetBinding(a, 1)
    O.SetBinding(b, 1)
    assertEqual(O.BoundTo(1), b)
    assertEqual(O.BindingOf(a), nil)
    O.SetBinding(b, 2)
    assertEqual(O.BoundTo(1), nil, "an outfit holds one key")
    assertEqual(O.BoundTo(2), b)
end)
