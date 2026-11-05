-- tests/test_settings.lua — the settings panel: page registration and order, the General tabs, the
-- composed Master controls, the global reset's wording, the H21 comment and the landing page (design
-- §4.2). P3 C12 pinned the scaffold; P4.23 adds the Behavior and Tooltips tabs, the Outfit Bar page and
-- the final order General → Outfit Bar → Profiles (design §9.3).
--
-- The Behavior and Tooltips reactions reach modules that have landed (QuickSlots, Tooltips, Compare);
-- the Delete all act reaches NS.Popups, which lands in P4.21, so it runs against a recorded fake
-- (design §12, the fake rule), as each reaction does here so the call is what the case asserts.

local T = _G.OUTFITTERREBORN_TEST
local spy = dofile(T.root .. "/tests/spy.lua")
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
    spy(NS, "Popups", { "ShowDeleteAll" }, function(popups)
        btn.onClick()
        -- red under: an onClick that calls NS.Outfits.DeleteAll directly, unconfirmed.
        assertEqual(popups.__count("ShowDeleteAll"), 1)
    end)
    T.mocks.StaticPopup_Hide("OUTFITTERREBORN_DELETE_ALL")
end)

-- ── Outfit Bar (design §4.2) ──────────────────────────────────────────────────────────────────

test("settings: the Outfit Bar page's tabs and rows, the position row never drawn", function()
    local out = {}
    for _, r in ipairs(NS.SchemaForPage("bar")) do out[#out + 1] = r.path .. "=" .. r.group end
    -- red under: a layout row registered on the Display tab
    assertEqual(table.concat(out, ","), "bar.shown=Display,bar.worn.style=Display,"
        .. "bar.combatAlpha=Display,bar.position=Display,"
        .. "bar.layout.mode=Layout,bar.vertical=Layout,bar.layout.perLine=Layout,bar.layout.growH=Layout,bar.layout.growV=Layout,"
        .. "bar.layout.padding=Layout,bar.layout.spacing=Layout,"
        .. "bar.icons.size=Icons,bar.icons.borderShow=Icons,bar.icons.borderStyle=Icons,bar.icons.borderSize=Icons,"
        .. "bar.icons.borderColor=Icons,bar.icons.useClassColorBorder=Icons,bar.icons.borderStyleFromSkin=Icons,"
        .. "bar.icons.borderColorFromSkin=Icons,"
        .. "bar.labels.show=Labels,bar.labels.font=Labels,bar.labels.fontSize=Labels,bar.labels.fontColor=Labels,"
        .. "bar.labels.useClassColorFont=Labels,bar.labels.fontFlags=Labels,bar.labels.fontShadow=Labels,"
        .. "bar.labels.fontFromSkin=Labels,bar.labels.fontColorFromSkin=Labels,bar.labels.fontShadowFromSkin=Labels,"
        .. "bar.bgColor=Frame,bar.useClassColorBg=Frame,bar.bgFromSkin=Frame,"
        .. "bar.frame.borderShow=Frame,bar.frame.borderStyle=Frame,bar.frame.borderSize=Frame,"
        .. "bar.frame.borderColor=Frame,bar.frame.useClassColorBorder=Frame,bar.frame.borderStyleFromSkin=Frame,"
        .. "bar.frame.borderColorFromSkin=Frame")
    -- skinning-§6: every color's companion, default on, in the row and in the defaults tree.
    for _, path in ipairs({ "bar.bgFromSkin", "bar.frame.borderStyleFromSkin", "bar.frame.borderColorFromSkin",
                            "bar.icons.borderStyleFromSkin", "bar.icons.borderColorFromSkin",
                            "bar.labels.fontFromSkin", "bar.labels.fontColorFromSkin", "bar.labels.fontShadowFromSkin" }) do
        assertEqual(NS.FindSchemaRow(path).default, true, path .. " row default")
        assertEqual(NS.GetSetting(path), true, path)
    end
    -- options-ui-§21: the composed rows carry the library's words, the companions after them ours.
    assertEqual(NS.FindSchemaRow("bar.frame.borderStyle").composed, true)
    assertEqual(NS.FindSchemaRow("bar.bgColor").composed, true)
    assertNil(NS.FindSchemaRow("bar.bgFromSkin").composed)
    assertNil(NS.FindSchemaRow("bar.frame.borderColorFromSkin").composed)
    assertEqual(NS.FindSchemaRow("bar.bgFromSkin").label, "Use the skin's background")
    local worn = NS.FindSchemaRow("bar.worn.style")
    assertEqual(worn.label, "Worn outfit highlight")
    assertTrue(worn.values.mark and worn.values.border and worn.values.both and worn.values.none, "the four styles")
    -- The label font block: From skin flags, its rows dimmed while the labels are off, never the swatch.
    assertEqual(NS.FindSchemaRow("bar.labels.fontFlags").default, "@skin")
    NS.db.profile.bar.labels.show = false
    assertTrue(NS.FindSchemaRow("bar.labels.fontSize").disabledIf(), "the size dims with the labels off")
    assertTrue(NS.FindSchemaRow("bar.labels.font").disabledIf(), "the face dims with the labels off")
    assertNil(NS.FindSchemaRow("bar.labels.fontColor").disabledIf, "the swatch is never grayed")
    NS.db.profile.bar.labels.show = true
    assertTrue(NS.FindSchemaRow("bar.labels.font").disabledIf(), "the face dims under Use the skin's font")
    NS.db.profile.bar.labels.fontFromSkin = false
    assertTrue(not NS.FindSchemaRow("bar.labels.font").disabledIf(), "the face is live with both off")
    NS.db.profile.bar.labels.fontFromSkin = true
    local function range(path, lo, hi, step)
        local r = NS.FindSchemaRow(path)
        assertTrue(r.min == lo and r.max == hi and r.step == step, path .. " range")
    end
    range("bar.layout.perLine", 0, 20, 1)
    range("bar.layout.padding", 0, 20, 1)
    range("bar.layout.spacing", 0, 20, 1)
    range("bar.icons.size", 16, 64, 1)
    assertEqual(NS.FindSchemaRow("bar.layout.perLine").label, "Per row or column (0 = one line)")
    for _, path in ipairs({ "bar.layout.growH", "bar.layout.growV" }) do
        local values = NS.FindSchemaRow(path).values
        assertEqual(values.auto, "Automatic", path)
    end
    assertEqual(NS.FindSchemaRow("bar.layout.growH").values.left, "Left")
    assertEqual(NS.FindSchemaRow("bar.layout.growV").values.up, "Up")
    assertEqual(NS.FindSchemaRow("bar.shown").label, "Show outfit bar")
    assertEqual(NS.FindSchemaRow("bar.vertical").tooltip, "One column per category.")
    local ca = NS.FindSchemaRow("bar.combatAlpha")
    assertEqual(ca.label, "Opacity in combat (%)")
    -- options-ui-§15: no "hide in combat" of the bar's own; the row points at General visibility.
    -- red under: a tooltip that does not end with the Multiplied-by sentence (options-ui-§21).
    assertEqual(ca.tooltip, "To hide the bar in combat, set General visibility on General > Master controls. Multiplied by Master opacity on General > Master controls.")
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

test("settings: the Outfit Bar page's Reset position writes the Master button's path, bar.position's default", function()
    local inst = T.load()
    local NS2 = inst.NS
    local hook = NS2.BAR_PAGE.afterGroup and NS2.BAR_PAGE.afterGroup["Display"]
    assertTrue(type(hook) == "function", "a button after the Display rows")
    local spec
    local real = NS2.Helpers.InlineButtonPair
    NS2.Helpers.InlineButtonPair = function(_, a) spec = a end
    hook({})
    NS2.Helpers.InlineButtonPair = real
    assertEqual(spec.text, "Reset position")
    NS2.db.profile.windows.bar = { point = "BOTTOMRIGHT", x = -5, y = 5 }
    spec.onClick()
    -- red under: a page button with a position of its own (options-ui-§15's second switch)
    assertEqual(NS2.GetSetting("bar.position"), "TOPLEFT 200 -200")
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
