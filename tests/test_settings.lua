-- tests/test_settings.lua — the settings panel: page registration and order, the General tabs, the
-- composed Master controls, the global reset's wording, the H21 comment and the landing page (design
-- §4.2). P3 C12 pinned the scaffold; P4.23 adds the Behavior and Tooltips tabs, the Outfit Bar page and
-- the final order General → Outfit Bar → Profiles (design §9.3).
--
-- The Behavior and Tooltips reactions reach modules that have landed (QuickSlots, Tooltips, Compare);
-- the Delete all act reaches NS.Popups, which lands in P4.21, so it runs against a recorded fake
-- (design §12, the fake rule), as each reaction does here so the call is what the case asserts.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "rb"))
    local s = f:read("*a")
    f:close()
    return (s:gsub("\r", ""))
end

test("settings: the parent category registers eagerly and every page body renders quietly", function()
    local inst = T.load()
    local M = inst.mocks
    assertTrue(M.__mainPanel ~= nil, "the parent category registered at OnInitialize")
    for _, name in ipairs({ "General", "Outfit Bar", "Profiles" }) do
        assertTrue(M.__subcategories[name] ~= nil, name .. " is not registered")
    end
    M.__resetPrinted()
    M.__mainPanel:__fire("OnShow")
    M.__subcategories["General"]:__fire("OnShow")
    M.__subcategories["Outfit Bar"]:__fire("OnShow")
    M.__subcategories["Profiles"]:__fire("OnShow")
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
end)

test("settings: the pages register General first, then Outfit Bar, and Profiles last", function()
    local inst = T.load()
    local order = {}
    for _, ctx in ipairs(inst.NS.Helpers.__pages()) do order[#order + 1] = ctx.pageKey or ctx.key end
    -- red under: settings\OutfitBar.lua listed after settings\Profiles.lua in the TOC.
    assertEqual(table.concat(order, ","), "general,bar,profiles")
end)

test("settings: General's tabs are Master controls, Behavior, Tooltips, Skin, then Keybindings last", function()
    -- options-ui-§13/§20: the schema tabs in first-appearance order, the host Keybindings tab last.
    -- The skin rows' group is the library's Skin tab's key ("Appearance"), so the tab takes its place.
    local seen, tabs = {}, {}
    for _, r in ipairs(NS.SchemaForPage("general")) do
        if not seen[r.group] then seen[r.group] = true; tabs[#tabs + 1] = r.group end
    end
    -- red under: the Behavior and Tooltips rows registered after the skin rows.
    assertEqual(table.concat(tabs, "|"), NS.Helpers.MASTER_GROUP .. "|Behavior|Tooltips|Appearance",
        "Keybindings is a host tab, not a schema one")
    local tab = NS.Helpers.KeybindingsTab({ bindings = {} })
    assertEqual(tab.key, "Keybindings")
    assertEqual(tab.before, nil, "with no `before` it is the strip's last")
end)

test("settings: Master controls is composed by the library, with the bar's notes", function()
    -- anti-patterns #68: the canonical block from H.MasterControls, never hand-built.
    local scale = NS.FindSchemaRow("scale")
    assertTrue(scale.tooltip:find("Applies to the outfit bar. The outfit window follows the character sheet.", 1, true) ~= nil,
        "the scale note: " .. tostring(scale.tooltip))
    local locked = NS.FindSchemaRow("locked")
    assertTrue(locked.tooltip:find("Locks the outfit bar.", 1, true) ~= nil, "the lock note")
    assertEqual(NS.FindSchemaRow("alpha").default, NS.defaults.profile.alpha, "Master opacity is not omitted")
    assertEqual(NS.FindSchemaRow("state.debugConsole").sessionOnly, true)
end)

-- ── Behavior and Tooltips (design §4.2) ────────────────────────────────────────────────────────

--- The `path=subgroup` list of one General tab, in panel order.
local function tabRows(group)
    local out = {}
    for _, r in ipairs(NS.SchemaForPage("general")) do
        if r.group == group then out[#out + 1] = r.path .. "=" .. tostring(r.subgroup) end
    end
    return table.concat(out, ",")
end

test("settings: Behavior holds the outfit changes, then the character sheet's one row", function()
    assertEqual(tabRows("Behavior"), "auto.enabled=Outfit changes,equip.muteSounds=Outfit changes,"
        .. "equip.showErrors=Outfit changes,equip.announceKeys=Outfit changes,quickSlots.enabled=Character sheet")
    assertEqual(NS.FindSchemaRow("auto.enabled").label, "Switch outfits automatically")
    assertEqual(NS.FindSchemaRow("equip.muteSounds").label, "Mute sound effects while changing outfits")
    assertEqual(NS.FindSchemaRow("equip.showErrors").label, "Show equip errors")
    assertEqual(NS.FindSchemaRow("equip.announceKeys").label, "Announce outfit changes from key bindings")
    assertEqual(NS.FindSchemaRow("quickSlots.enabled").label,
        "Open the item flyout when you click an empty slot or drop an item on it")
    assertTrue(NS.FindSchemaRow("auto.enabled").tooltip:find("Turning this off stops every trigger", 1, true) ~= nil)
    -- The binder's SETTINGS_CHANGED handler is auto.enabled's one route (design §6.9).
    -- red under: an onChange on the auto.enabled row.
    assertNil(NS.FindSchemaRow("auto.enabled").onChange, "auto.enabled takes no onChange")
end)

test("settings: Tooltips holds the used-by line and the comparison", function()
    assertEqual(tabRows("Tooltips"), "tooltip.usedBy=nil,tooltip.compare=nil")
    assertEqual(NS.FindSchemaRow("tooltip.usedBy").label, "Show which outfits use an item")
    assertEqual(NS.FindSchemaRow("tooltip.compare").label, "Compare items with your outfits")
end)

test("settings: the flyout and tooltip rows react through their modules", function()
    local inst = T.load()
    local NSi = inst.NS
    local qs = T.fake(NSi, "QuickSlots", { SetEnabled = true })
    local tips = T.fake(NSi, "Tooltips", { Refresh = true })
    local cmp = T.fake(NSi, "Compare", { Refresh = true })
    assertTrue(NSi.SetByPath("quickSlots.enabled", false))
    assertTrue(NSi.SetByPath("tooltip.usedBy", false))
    assertTrue(NSi.SetByPath("tooltip.compare", false))
    -- red under: the quickSlots.enabled row without its onChange.
    assertEqual(qs.__count("SetEnabled"), 1)
    assertEqual(qs.__calls[1][2], false, "SetEnabled takes the new value")
    -- red under: either tooltip row without its onChange.
    assertEqual(tips.__count("Refresh"), 1)
    assertEqual(cmp.__count("Refresh"), 1)
    assertEqual(NSi.db.profile.tooltip.compare, false)
end)

test("settings: Delete all outfits closes Behavior with no heading and asks through the popup", function()
    -- options-ui-§7: an act at a tab's end is appended through afterGroup, under no heading of its
    -- own. The hook fires after the group's last row, so the button is the tab's last control.
    local after = NS.GENERAL_AFTER_GROUP
    assertEqual(type(after["Behavior"]), "function")
    assertEqual(type(after[NS.Helpers.MASTER_GROUP]), "function", "the Master tail is still hooked")
    local H = NS.Helpers
    local pairs_, sections = {}, 0
    local savedPair, savedSection = H.InlineButtonPair, H.Section
    H.InlineButtonPair = function(_, left, right) pairs_[#pairs_ + 1] = { left, right } end
    H.Section = function() sections = sections + 1 end
    local ok, err = pcall(after["Behavior"], {})
    H.InlineButtonPair, H.Section = savedPair, savedSection
    assertTrue(ok, tostring(err))
    assertEqual(#pairs_, 1)
    -- red under: the act drawn under a Section heading.
    assertEqual(sections, 0, "the act carries no heading")
    local btn = pairs_[1][1]
    assertEqual(btn.text, "Delete all outfits\226\128\166")
    assertNil(pairs_[1][2], "one button, alone on its line")
    local popups = T.fake(NS, "Popups", { ShowDeleteAll = true })
    btn.onClick()
    -- red under: an onClick that calls NS.Outfits.DeleteAll directly, unconfirmed.
    assertEqual(popups.__count("ShowDeleteAll"), 1)
end)

-- ── Outfit Bar (design §4.2) ──────────────────────────────────────────────────────────────────

test("settings: the Outfit Bar page is one Display tab, the position row never drawn", function()
    local out = {}
    for _, r in ipairs(NS.SchemaForPage("bar")) do out[#out + 1] = r.path .. "=" .. r.group end
    assertEqual(table.concat(out, ","), "bar.shown=Display,bar.vertical=Display,bar.showBackground=Display,"
        .. "bar.combatAlpha=Display,bar.position=Display")
    assertEqual(NS.FindSchemaRow("bar.shown").label, "Show outfit bar")
    assertEqual(NS.FindSchemaRow("bar.vertical").tooltip, "One column per category.")
    assertEqual(NS.FindSchemaRow("bar.showBackground").label, "Show background")
    local ca = NS.FindSchemaRow("bar.combatAlpha")
    assertEqual(ca.label, "Opacity in combat (%)")
    assertEqual(ca.tooltip, "Multiplied by Master opacity on General > Master controls.")
    assertTrue(ca.min == 0 and ca.max == 1 and ca.step == 0.05 and ca.isPercent == true, "the 0..1 percent slider")
    -- red under: the position row without skipRender (the panel would draw a text box for it).
    assertEqual(NS.FindSchemaRow("bar.position").skipRender, true)
    assertEqual(NS.FindSchemaRow("bar.position").label, "Outfit bar position")
    assertEqual(NS.BAR_PAGE.key, "bar")
    assertEqual(NS.BAR_PAGE.title, "Outfit Bar")
    assertEqual(NS.BAR_PAGE.panelName, "OutfitterRebornBarPanel")
    assertEqual(NS.BAR_PAGE.defaultsTooltip,
        "Restore every Outfit Bar setting to its default. The bar's position is reset too.")
end)

test("settings: the global reset confirms with options-ui-§12's one wording, verbatim", function()
    local inst = T.load()
    local d = inst.mocks.StaticPopupDialogs.OUTFITTERREBORN_RESET_ALL
    assertEqual(d.text, "Reset this profile to the addon's defaults? Everything you have configured or added in it "
        .. "is discarded \226\128\148 your other profiles are not affected.")
    assertEqual(d.button1, "Yes")
    assertEqual(d.button2, "No")
    assertTrue(d.timeout == 0 and d.whileDead == true and d.hideOnEscape == true)
end)

test("settings: accepting the reset restores the profile and says so", function()
    local inst = T.load()
    local NSi, M = inst.NS, inst.mocks
    NSi.SetByPath("visibility", "never")
    M.__resetPrinted()
    M.StaticPopupDialogs.OUTFITTERREBORN_RESET_ALL.OnAccept()
    assertEqual(NSi.GetSetting("visibility"), "always")
    local said = false
    for _, line in ipairs(M.__printed()) do
        if line:find("All settings reset to defaults.", 1, true) then said = true end
    end
    assertTrue(said, "the reset printed no line")
end)

test("settings: the H21 comment records why options are not split into LoadOnDemand", function()
    local text = readFile("settings/OptionsSetup.lua")
    assertTrue(text:find("Options stay in-addon: three subcategories, below options-ui-§4's five-subpanel threshold (DpsRace\n-- precedent).", 1, true) ~= nil,
        "the H21 comment is missing from settings/OptionsSetup.lua")
end)

test("settings: the landing page has the logo, one row per verb and the credits line", function()
    local L = NS.LANDING
    assertEqual(L.logo, NS.Constants.LOGO)
    assertEqual(L.sections[1].heading, "Slash Commands")
    assertEqual(#L.sections[1].rows(), #NS.COMMANDS)
    assertEqual(L.sections[2].rows()[1], "Originally created by John Stephen (mundocani). Maintained by "
        .. "aDd1kTeD2Ka0s, with thanks to Nulian and every earlier maintainer, tester and translator.")
    assertTrue(L.notes():find("equipment changes", 1, true) ~= nil, "the notes are the TOC's")
end)

test("settings: the Profiles page says outfits are per character, above AceDBOptions' controls", function()
    local inst = T.load()
    local M = inst.mocks
    M.__subcategories["Profiles"]:__fire("OnShow")
    local dialog = M.LibStub("AceConfigDialog-3.0")
    assertEqual(dialog.__lastOpen and dialog.__lastOpen.name, "OutfitterReborn-Profiles")
    local tbl = M.LibStub("AceConfig-3.0").__registered["OutfitterReborn-Profiles"]
    local note = tbl and tbl.args.outfitsNote
    assertTrue(note ~= nil, "no note row on the Profiles table")
    assertEqual(note.type, "description")
    assertEqual(note.order, 0, "the note leads the page")
    assertEqual(note.name, "Profiles hold settings only. Outfits belong to each character and are not changed "
        .. "by switching, copying or resetting a profile.")
end)

test("settings: library absent, the addon still loads and the reset still lands", function()
    local inst = T.load{ libFiles = {} }
    local NSi = inst.NS
    assertTrue(NSi.SetByPath("enabled", false))
    NSi.Helpers.RestoreAllDefaults()
    assertEqual(NSi.GetSetting("enabled"), true, "the degraded reset restored the profile")
end)
