-- tests/test_settings.lua — the settings panel: page registration and order, the General tabs, the
-- composed Master controls, the global reset's wording, the H21 comment and the landing page (design
-- §4.2). P3 C12 pins the scaffold; P4.23 adds the Behavior, Tooltips and Skin tabs and the Outfit Bar
-- page, and the final order General → Outfit Bar → Profiles (design §9.3).

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

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
    for _, name in ipairs({ "General", "Profiles" }) do
        assertTrue(M.__subcategories[name] ~= nil, name .. " is not registered")
    end
    M.__resetPrinted()
    M.__mainPanel:__fire("OnShow")
    M.__subcategories["General"]:__fire("OnShow")
    M.__subcategories["Profiles"]:__fire("OnShow")
    assertEqual(#M.__printed(), 0, "a render printed: " .. tostring(M.__printed()[1]))
end)

test("settings: the pages register General first and Profiles last", function()
    local inst = T.load()
    local order = {}
    for _, ctx in ipairs(inst.NS.Helpers.__pages()) do order[#order + 1] = ctx.pageKey or ctx.key end
    assertEqual(table.concat(order, ","), "general,profiles", "Outfit Bar goes between them in P4.23")
end)

test("settings: General's tabs are Master controls, then Skin, then Keybindings last", function()
    -- options-ui-§13/§20: the schema tabs in first-appearance order, the host Keybindings tab last.
    -- The skin rows' group is the library's Skin tab's key ("Appearance"), so the tab takes its place.
    -- P4.23 puts Behavior and Tooltips between Master controls and Skin.
    local seen, tabs = {}, {}
    for _, r in ipairs(NS.SchemaForPage("general")) do
        if not seen[r.group] then seen[r.group] = true; tabs[#tabs + 1] = r.group end
    end
    assertEqual(table.concat(tabs, "|"), NS.Helpers.MASTER_GROUP .. "|Appearance",
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
