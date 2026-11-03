-- tests/test_keybinds.lua — the key bindings as the player meets them (launcher-§6, options-ui-§20,
-- design §4.4): Bindings.xml in the addon's own category, NS.BINDINGS in file order with its labels,
-- the hidden non-secure buttons and their press, and the General page's last tab, `Keybindings`,
-- drawn by the library. P3 C13 pins the first row, Show window; P4.24 adds the other 13 (the wear
-- keys with their anti-panic and announce rules, AutoOn, AutoOff, UpdateOutfit) and their cases.
-- Capture, conflict and settings-window cases are the library's (testing-§8) and are not repeated.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SHOW = "CLICK OutfitterRebornToggleWindow:LeftButton"
local COMMANDS = { SHOW }
local LABELS = {
    [SHOW] = "Toggle outfit window",
}

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
