-- tests/test_outfit_menu.lua — P4.21 (design §7.5, INV §7.7): modules/OutfitMenu.lua's context menu,
-- its rows per section, the submenus, the toggles that keep it open, and where each row leads.
--
-- The menu is drawn through the real NS.OpenMenu seam (core/WidgetsSetup.lua); tests/dialog_scene.lua
-- records W.ContextMenu's rows. The seam hands the library the whole tree once (Widgets minor 23's
-- cascading `submenu` rows, design 2026-11-05 G4), so `click` on a submenu row records its child
-- level as the newest menu, as the library opens it beside the parent. NS.Bank runs against a
-- recorded fake where a case asserts which move a row asks for; the bank's own behavior is test_bank's.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dialog_scene.lua")(T)

local function plain(label) return (tostring(label):gsub("|T.-|t%s*", ""):gsub("%s+$", "")) end

local function plainLabels(ctl)
    local out = {}
    for _, r in ipairs(ctl.menus[#ctl.menus].rows) do
        out[#out + 1] = r.divider and "-" or plain(r.label)
    end
    return table.concat(out, "|")
end

-- An Accessory outfit with a stat cfg and the RIDING trigger, and a Complete one with nothing.
local function outfits(NS)
    local O = NS.Outfits
    local acc = O.Create("Ride", { FeetSlot = { id = 0 } }, { trigger = "RIDING", fields = { stat = { { stat = "STA" } } } })
    local naked = {}
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do naked[slot] = { id = 0 } end
    local comp = O.Create("Bare", naked)
    return acc, comp
end

local function open(NS, ctl, id)
    ctl.menus = {}
    assertTrue(NS.OutfitMenu.Open({}, id), "the menu did not open")
end

-- Click a row of the newest menu by its label: a submenu row records its child level (the library
-- opens it beside the parent, the parent kept), any other row runs its click as the library does.
local function click(ctl, text)
    local r = ctl.row(text)
    assertTrue(r ~= nil, "no row " .. text .. " in " .. ctl.labels())
    if r.submenu then
        ctl.menus[#ctl.menus + 1] = { rows = r.submenu, parent = r }
    else
        r.onClick(nil, r)
    end
    return r
end

-- The first trigger the picker offers, with params (`true`) or without (`false`): its category and descriptor.
local function triggerWith(NS, params)
    local class = NS.Compat.PlayerClass()
    for _, cat in ipairs(NS.Triggers.Categories(class)) do
        for _, d in ipairs(NS.Triggers.List(cat, class)) do
            if (#(d.params or {}) > 0) == params then return cat, d end
        end
    end
    error("no trigger " .. (params and "with" or "without") .. " params")
end

-- The row of `rows` whose plain label is `text` exactly.
local function exact(rows, text)
    for _, r in ipairs(rows) do
        if r.label and plain(r.label) == text then return r end
    end
    return nil
end

test("menu: NS.OutfitMenu is published", function()
    assertEqual(type(T.NS.OutfitMenu), "table")
    assertEqual(type(T.NS.OutfitMenu.Open), "function")
    assertEqual(type(T.NS.OutfitMenu.CategoryLabel), "function")
end)

test("menu: the rows per section are legacy's, less Void Storage and the script editor", function()
    local NS, _, ctl = scene()
    local acc, comp = outfits(NS)
    open(NS, ctl, acc)
    -- red under: fillGeneral without the Unequip others row (INV §7.7).
    assertEqual(plainLabels(ctl), "Ride|Rename...|Key binding|Title|Bank|"
        .. "On equip, unequip other Accessory outfits|Ignore in comparison tooltips|Delete|-|"
        .. "Update to current items|Rebuild for " .. NS.Stats.ConfigName({ { stat = "STA" } }) .. "|Rebuild for...|-|"
        .. "Automation: " .. NS.Triggers.Get("RIDING").name .. "|Trigger settings...|Turn trigger off|"
        .. "Disable outfit in combat|-|Show in outfit bar|Change icon...")
    open(NS, ctl, comp)
    local all = plainLabels(ctl)
    -- red under: Unequip others offered on a Complete outfit; "Rebuild for <stat>" without a stat cfg.
    assertNil(all:find("unequip other", 1, true), "Unequip others on a Complete outfit")
    assertNil(all:find("Rebuild for S", 1, true), "Rebuild for <stat> without a stat cfg")
    assertTrue(all:find("Automation: None", 1, true) ~= nil)
    for _, gone in ipairs({ "Void Storage", "Edit script", "Script", "...." }) do
        assertNil(all:find(gone, 1, true), gone)
    end
    -- The doubled "..." (INV §7.7 Fix): one ellipsis.
    assertEqual(plain(ctl.row("Change icon").label), "Change icon...")
end)

test("menu: Bank rows are disabled with the bank closed, with a reason, and each asks for its move", function()
    local NS, _, ctl = scene()
    local acc = outfits(NS)
    open(NS, ctl, acc)
    click(ctl, "Bank")
    assertEqual(plainLabels(ctl), "Deposit all items to bank|Deposit unique items to bank|Withdraw items from bank|-|"
        .. "Deposit other outfits to bank|Withdraw other outfits from bank")
    for _, r in ipairs(ctl.menus[#ctl.menus].rows) do
        if not r.divider then
            -- red under: the Bank rows built with no SetEnabled (they are live with the bank closed).
            assertTrue(r.disabled, r.label .. " is enabled with the bank closed")
            assertEqual(r.tooltip, NS.L["The bank must be open"])
        end
    end
    local bank = T.fake(NS, "Bank", { IsOpen = function() return true end, Deposit = true, Withdraw = true,
                                      DepositOthers = true, WithdrawOthers = true })
    open(NS, ctl, acc)
    click(ctl, "Bank")
    assertNil(ctl.row("Deposit all").disabled)
    for _, label in ipairs({ "Deposit all", "Deposit unique", "Withdraw items", "Deposit other", "Withdraw other" }) do
        open(NS, ctl, acc)
        click(ctl, "Bank")
        click(ctl, label)
    end
    local moves = {}
    for _, c in ipairs(bank.__calls) do
        if c[1] ~= "IsOpen" then moves[#moves + 1] = c[1] .. "(" .. tostring(c[2]) .. "," .. tostring(c[3]) .. ")" end
    end
    -- red under: Deposit unique calling Bank.Deposit without its uniqueOnly flag.
    assertEqual(table.concat(moves, " "), ("Deposit(%s,nil) Deposit(%s,true) Withdraw(%s,nil) DepositOthers(%s,nil) "
        .. "WithdrawOthers(%s,nil)"):format(acc, acc, acc, acc, acc))
end)

test("menu: the key binding rows name each key's holder and bind the outfit", function()
    local NS, _, ctl = scene()
    local acc = outfits(NS)
    local tank = NS.Outfits.Create("Tank", { HeadSlot = { id = 0 } })
    NS.Outfits.SetBinding(tank, 3)
    open(NS, ctl, acc)
    click(ctl, "Key binding")
    -- red under: the binding labels built without the holder ("Outfit 3").
    assertEqual(plain(ctl.menus[#ctl.menus].rows[4].label), "Outfit 3 (Tank)")
    assertEqual(plain(ctl.menus[#ctl.menus].rows[3].label), "Outfit 2")
    assertEqual(#ctl.menus[#ctl.menus].rows, 11, "None and Outfit 1-10")
    click(ctl, "Outfit 3")
    assertEqual(NS.Outfits.BindingOf(acc), 3)
    assertNil(NS.Outfits.BindingOf(tank), "the key left its old holder")
    open(NS, ctl, acc)
    click(ctl, "Key binding")
    click(ctl, "None")
    assertNil(NS.Outfits.BindingOf(acc))
end)

test("menu: the Title submenu lists the known titles, a secret one skipped, 30 a level with More", function()
    local NS, M, ctl = scene()
    local acc = outfits(NS)
    local titles = {}
    for i = 1, 33 do titles[i] = { ("Title %02d %%s"):format(34 - i), true } end
    titles[34] = { "Unknown %s", false }
    M.__world.titles = titles
    local name = M.GetTitleName
    M.GetTitleName = function(id)
        if id == 5 then return T.secret("Title 29") end
        return name(id)
    end
    open(NS, ctl, acc)
    click(ctl, "Title")
    local rows = ctl.menus[#ctl.menus].rows
    -- None, then 30 titles, then More: 32 known ones less the secret one.
    assertEqual(#rows, 32)
    assertEqual(plain(rows[1].label), "None")
    -- red under: KnownTitles unsorted (the client's order is Title 33 first).
    assertEqual(plain(rows[2].label), "Title 01")
    assertTrue(plainLabels(ctl):find("Title 29", 1, true) == nil, "the secret title was listed")
    assertEqual(plain(rows[32].label), "More")
    click(ctl, "More")
    assertEqual(plainLabels(ctl), "Title 32|Title 33")
    click(ctl, "Title 33")
    assertEqual(NS.Outfits.Get(acc).titleID, 1)
    M.__world.titleCalls = nil
    NS.Stack.Wear(acc, { now = true })
    M.__fireTimers()
    assertEqual(M.__world.currentTitle, 1, "the title was not shown after the pick")
    open(NS, ctl, acc)
    click(ctl, "Title")
    click(ctl, "None")
    assertNil(NS.Outfits.Get(acc).titleID)
end)

test("menu: a title pick's delayed show is canceled by the stand-down (slash-commands-§7)", function()
    -- red under: show the title with the bare `C_Timer.After(TITLE_DELAY, ...)` in setTitle
    -- (modules/OutfitMenu.lua): no stand-down can cancel it, so it stays armed while disabled
    local NS, M, ctl = scene()
    local acc = outfits(NS)
    open(NS, ctl, acc)
    click(ctl, "Title")
    local before = #M.__timers()
    click(ctl, "Private")
    assertEqual(NS.Outfits.Get(acc).titleID, 1)
    assertTrue(#M.__timers() > before, "the pick armed no delayed show; nothing below can fail")
    assertTrue(NS.SetByPath("enabled", false))
    assertEqual(#M.__timers(), 0, "the title's delayed show survived the stand-down")
end)

test("menu: the toggles keep the menu open, Turn trigger off writes outfit.trigger.disabled", function()
    local NS, _, ctl = scene()
    local acc, comp = outfits(NS)
    open(NS, ctl, acc)
    local off = ctl.row("Turn trigger off")
    assertTrue(off.keepOpen, "a toggle closed the menu")
    assertNil(off.disabled)
    local edited = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.OUTFIT_EDITED, function(_, id, what) edited[#edited + 1] = id .. ":" .. what end)
    off.onClick(nil, off)
    assertTrue(NS.Outfits.Get(acc).trigger.disabled)
    -- red under: the row writing rec.trigger.disabled itself, past NS.SetByPath (no OUTFIT_EDITED, no rebind).
    assertEqual(edited[1], acc .. ":trigger")
    assertTrue(off.label:find("|T", 1, true) ~= nil, "the toggled row does not show its tick")
    local combat = ctl.row("Disable outfit in combat")
    combat.onClick(nil, combat)
    assertTrue(NS.Outfits.Get(acc).trigger.combatDisabled)
    local others = ctl.row("unequip other")
    others.onClick(nil, others)
    assertTrue(NS.Outfits.Get(acc).unequipOthers)
    local cmp = ctl.row("Ignore in comparison")
    cmp.onClick(nil, cmp)
    assertTrue(NS.Outfits.Get(acc).ignoreComparisons)
    local bar = ctl.row("Show in outfit bar")
    bar.onClick(nil, bar)
    assertTrue(NS.Outfits.Get(acc).bar.hide, "Show in outfit bar did not hide it")
    bar.onClick(nil, bar)
    assertFalse(NS.Outfits.Get(acc).bar.hide)
    open(NS, ctl, comp)
    -- red under: the trigger toggles left enabled on an outfit with no trigger.
    assertTrue(ctl.row("Turn trigger off").disabled)
    assertTrue(ctl.row("Disable outfit in combat").disabled)
end)

test("menu: picking a trigger writes outfit.trigger.id and opens its settings when it has params", function()
    local NS, _, ctl = scene()
    local _, comp = outfits(NS)
    open(NS, ctl, comp)
    click(ctl, "Automation")
    assertEqual(plain(ctl.menus[#ctl.menus].rows[1].label), "No trigger")
    click(ctl, NS.OutfitMenu.CategoryLabel("TRADE"))
    local riding = NS.Triggers.Get("RIDING")
    local r = ctl.row(riding.name)
    assertEqual(plain(r.label), riding.name .. "...", "a trigger with params is marked")
    assertEqual(r.tooltip, riding.desc)
    r.onClick(nil, r)
    assertEqual(NS.Outfits.Get(comp).trigger.id, "RIDING")
    -- red under: the pick without NS.TriggerDialog.Open.
    assertTrue(NS.TriggerDialog.IsOpen(), "the trigger's settings did not open")
    NS.TriggerDialog.Close("test")
    open(NS, ctl, comp)
    click(ctl, "Automation")
    click(ctl, "No trigger")
    assertNil(NS.Outfits.Get(comp).trigger)
    open(NS, ctl, comp)
    click(ctl, "Trigger settings")
    assertTrue(NS.TriggerDialog.IsOpen())
end)

test("menu: Delete, Update and Rebuild ask through popups carrying the id; the dialogs open", function()
    local NS, M, ctl = scene()
    local acc = outfits(NS)
    open(NS, ctl, acc)
    click(ctl, "Delete")
    local p = M.__popups[#M.__popups]
    assertEqual(p.which, "OUTFITTERREBORN_CONFIRM_DELETE")
    assertEqual(p.data, acc)
    open(NS, ctl, acc)
    click(ctl, "Update to current")
    assertEqual(M.__popups[#M.__popups].which, "OUTFITTERREBORN_CONFIRM_SET_CURRENT")
    assertEqual(M.__popups[#M.__popups].data, acc)
    open(NS, ctl, acc)
    click(ctl, "Rebuild for S")
    p = M.__popups[#M.__popups]
    assertEqual(p.which, "OUTFITTERREBORN_CONFIRM_REBUILD")
    assertEqual(p.data.id, acc)
    assertEqual(p.data.cfg[1].stat, "STA")
    open(NS, ctl, acc)
    click(ctl, "Rebuild for...")
    assertTrue(NS.RebuildDialog.IsOpen())
    open(NS, ctl, acc)
    click(ctl, "Rename")
    assertTrue(NS.OutfitDialog.IsOpen())
    open(NS, ctl, acc)
    click(ctl, "Change icon")
    assertTrue(NS.IconBrowser.IsOpen())
end)

-- ── cascading levels (design 2026-11-05 G4; LibKa0s Widgets minor 23) ─────────────────────────

test("menu: the whole tree goes to the library once, each nested level as a submenu row", function()
    local NS, _, ctl = scene()
    local acc = outfits(NS)
    open(NS, ctl, acc)
    -- red under: the old replay, a submenu row whose click reopened the one menu with its level.
    assertEqual(#ctl.menus, 1, "the menu opened more than once")
    assertTrue(ctl.menus[1].opts.cursor, "the menu opens at the cursor")
    for _, name in ipairs({ "Key binding", "Title", "Bank", "Automation" }) do
        local r = ctl.row(name)
        assertEqual(type(r.submenu), "table", name .. " carries no submenu")
        assertNil(r.onClick, name .. " runs a click of its own")
        -- The library draws the arrow: the label carries no chevron markup.
        assertNil(r.label:find("|T", 1, true), name .. " draws its own chevron")
    end
    assertEqual(#ctl.row("Key binding").submenu, 11, "None and Outfit 1-10")
    local cat = triggerWith(NS, false)
    local auto = ctl.row("Automation").submenu
    -- Two deep: Automation > category > trigger.
    local level = exact(auto, NS.OutfitMenu.CategoryLabel(cat))
    assertTrue(level ~= nil and type(level.submenu) == "table", "the category opens no level")
    click(ctl, "Key binding")
    assertEqual(#ctl.menus, 2)
    assertEqual(plain(ctl.menus[2].rows[1].label), "None")
end)

test("menu: Key binding picks are radios that keep the menu open, tick the key and rename its holders", function()
    local NS, _, ctl = scene()
    local acc = outfits(NS)
    local tank = NS.Outfits.Create("Tank", { HeadSlot = { id = 0 } })
    NS.Outfits.SetBinding(tank, 3)
    open(NS, ctl, acc)
    click(ctl, "Key binding")
    local rows = ctl.menus[#ctl.menus].rows
    for i, r in ipairs(rows) do
        -- red under: binding rows recorded as plain buttons (the menu closes on a pick, no tick).
        assertTrue(r.radio, "row " .. i .. " is not a radio")
        assertTrue(r.keepOpen, "row " .. i .. " closes the menu")
        assertEqual(type(r.selected), "function", "row " .. i .. " has no tick predicate")
    end
    assertTrue(rows[1].selected(rows[1]), "None is not ticked on an unbound outfit")
    assertFalse(rows[4].selected(rows[4]))
    click(ctl, "Outfit 3")
    assertEqual(NS.Outfits.BindingOf(acc), 3)
    -- The library repaints the open level from these same tables: the tick moved, the holder renamed.
    assertTrue(rows[4].selected(rows[4]), "Outfit 3 is not ticked after the pick")
    assertFalse(rows[1].selected(rows[1]), "None stays ticked")
    -- red under: a keep-open pick that leaves the labels the first fill wrote.
    assertEqual(plain(rows[4].label), "Outfit 3 (Ride)")
    assertEqual(#ctl.menus, 1 + 1, "the pick reopened the menu")
end)

test("menu: Title picks and a trigger without params keep the menu open; the parent's label follows", function()
    local NS, _, ctl = scene()
    local _, comp = outfits(NS)
    open(NS, ctl, comp)
    local root = ctl.menus[1].rows
    click(ctl, "Title")
    local none = ctl.row("None")
    assertTrue(none.radio and none.keepOpen, "the Title rows are not keep-open radios")
    assertTrue(none.selected(none), "None is not ticked with no title")
    local private = ctl.row("Private")
    click(ctl, "Private")
    assertTrue(private.selected(private), "the picked title is not ticked")
    assertFalse(none.selected(none))
    -- A trigger without params: picked in place, the root's Automation row renamed.
    local cat, d = triggerWith(NS, false)
    assertTrue(exact(root, "Turn trigger off").disabled, "Turn trigger off is live with no trigger")
    ctl.menus = { ctl.menus[1] }
    click(ctl, "Automation")
    local noTrigger = ctl.row("No trigger")
    assertTrue(noTrigger.radio and noTrigger.keepOpen and noTrigger.selected(noTrigger), "No trigger")
    click(ctl, NS.OutfitMenu.CategoryLabel(cat))
    local r = exact(ctl.menus[#ctl.menus].rows, d.name)
    assertTrue(r ~= nil, "no row " .. d.name)
    assertTrue(r.radio and r.keepOpen, "a trigger without params closes the menu")
    r.onClick(nil, r)
    assertEqual(NS.Outfits.Get(comp).trigger.id, d.id)
    assertFalse(NS.TriggerDialog.IsOpen(), "a trigger without params opened its settings")
    assertTrue(r.selected(r), "the picked trigger is not ticked")
    assertFalse(noTrigger.selected(noTrigger))
    -- red under: refreshing the picked level only (the root still says None, the toggles stay off).
    assertTrue(exact(root, "Automation: " .. d.name) ~= nil, "the root's Automation label did not follow")
    assertNil(exact(root, "Turn trigger off").disabled, "Turn trigger off stays disabled")
end)

test("menu: rows that open a dialog, popup or window, and the bank moves, act and close", function()
    local NS, _, ctl = scene()
    local acc, comp = outfits(NS)
    open(NS, ctl, acc)
    for _, name in ipairs({ "Rename...", "Delete", "Update to current items", "Rebuild for...",
                            "Trigger settings...", "Change icon..." }) do
        local r = exact(ctl.menus[1].rows, name)
        assertTrue(r ~= nil, "no row " .. name)
        -- red under: a seam marking every row keepOpen (the menu would cover the dialog).
        assertNil(r.keepOpen, name .. " keeps the menu open")
        assertNil(r.radio, name .. " is a radio")
    end
    assertNil(ctl.row("Rebuild for S").keepOpen)
    click(ctl, "Bank")
    for _, r in ipairs(ctl.menus[#ctl.menus].rows) do
        if not r.divider then assertNil(r.keepOpen, plain(r.label) .. " keeps the menu open") end
    end
    open(NS, ctl, comp)
    local cat, d = triggerWith(NS, true)
    click(ctl, "Automation")
    click(ctl, NS.OutfitMenu.CategoryLabel(cat))
    local r = exact(ctl.menus[#ctl.menus].rows, d.name .. "...")
    assertTrue(r ~= nil, "no row " .. d.name .. "...")
    -- red under: every trigger pick a keep-open radio (its settings dialog would sit under the menu).
    assertNil(r.keepOpen, "a trigger with params keeps the menu open")
    assertNil(r.radio, "a trigger with params is a radio")
end)

-- The client's MenuUtil, for the library-absent load: each description recorded with its responder.
local function menuUtil(M)
    local made = {}
    local function desc(kind, text, responder)
        local d = { kind = kind, text = text, responder = responder }
        made[#made + 1] = d
        function d.CreateButton(_, t, cb) return desc("button", t, cb) end
        function d.CreateRadio(_, t, _, set, data) return desc("radio", t, function() return set(data) end) end
        function d.CreateCheckbox(_, t, _, set, data) return desc("checkbox", t, function() return set(data) end) end
        function d.CreateTitle() return {} end
        function d.CreateDivider() return {} end
        function d.SetEnabled() end
        function d.SetTooltip() end
        return d
    end
    M.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, desc("root")) end }
    return function(text)
        for _, d in ipairs(made) do
            if d.text and plain(d.text):find(text, 1, true) == 1 then return d end
        end
        error("no description " .. text)
    end
end

test("menu: on the client's MenuUtil only keep-open rows answer Refresh, the rest close", function()
    local inst = T.load({ libFiles = {} })
    local NS, M = inst.NS, inst.mocks
    local acc = NS.Outfits.Create("Ride", { FeetSlot = { id = 0 } })
    M.MenuResponse = { Open = 1, Refresh = 2, Close = 3, CloseAll = 4 }
    local find = menuUtil(M)
    assertTrue(NS.OutfitMenu.Open({}, acc), "the degraded menu did not open")
    -- red under: radios handed to MenuUtil as they are (a responder returning nil closes the tree).
    assertEqual(find("Outfit 2").responder(), 2, "a binding pick closes the client's menu")
    assertEqual(NS.Outfits.BindingOf(acc), 2)
    assertEqual(find("Ignore in comparison").responder(), 2, "a toggle closes the client's menu")
    -- red under: a seam that answers Refresh from every row.
    assertNil(find("Rename").responder(), "Rename keeps the client's menu open")
    NS.OutfitDialog.Close("test")
    -- Without MenuResponse the keep-open rows answer nil (close) rather than raise.
    M.MenuResponse = nil
    find = menuUtil(M)
    assertTrue(NS.OutfitMenu.Open({}, acc))
    assertNil(find("Outfit 4").responder())
    assertEqual(NS.Outfits.BindingOf(acc), 4)
    M.MenuUtil = nil
end)

test("menu: nothing opens for an unknown id or while stood down", function()
    local NS, _, ctl = scene()
    local acc = outfits(NS)
    ctl.menus = {}
    assertFalse(NS.OutfitMenu.Open({}, "o999"))
    assertFalse(NS.OutfitMenu.Open({}, "preview:1"))
    NS.SetByPath("enabled", false)
    -- red under: Open without its NS.IsStoodDown() check.
    assertFalse(NS.OutfitMenu.Open({}, acc))
    assertEqual(#ctl.menus, 0)
end)

test("menu: the class category reads the client's class name, the rest their own labels", function()
    local NS = scene({ class = "DRUID" })
    local CL = NS.OutfitMenu.CategoryLabel
    assertEqual(CL("GENERAL"), "General"); assertEqual(CL("TRADE"), "Activities"); assertEqual(CL("PVP"), "PvP")
    assertEqual(CL("QUEST"), "Questing"); assertEqual(CL("ENTERTAIN"), "Entertainment")
    assertEqual(CL("SPEC"), "Specialization")
    assertEqual(CL("CLASS"), NS.Compat.PlayerClassName())
end)
