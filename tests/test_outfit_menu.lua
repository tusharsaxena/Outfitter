-- tests/test_outfit_menu.lua — P4.21 (design §7.5, INV §7.7): modules/OutfitMenu.lua's context menu,
-- its rows per section, the submenus, the toggles that keep it open, and where each row leads.
--
-- The menu is drawn through the real NS.OpenMenu seam (core/WidgetsSetup.lua); tests/dialog_scene.lua
-- records W.ContextMenu's rows, so a submenu row's click reopens the recorder one level down, as the
-- library's menu does. NS.Bank runs against a recorded fake where a case asserts which move a row
-- asks for; the bank's own behaviour is test_bank's.

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

-- Click a row of the newest menu by its label (a submenu row opens its level in the recorder).
local function click(ctl, text)
    local r = ctl.row(text)
    assertTrue(r ~= nil, "no row " .. text .. " in " .. ctl.labels())
    r.onClick(nil, r)
    return r
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
    assertTrue(NS.IconChooser.IsOpen())
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
