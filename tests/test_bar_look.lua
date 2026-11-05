-- tests/test_bar_look.lua — the outfit bar's look (modules/Bar_Chrome.lua): the label's font and
-- color through the skin seam, the border color's skin companion on the player's plate and icon edge,
-- test mode without the library, the icon and frame border switches and the Grouping row (smoke
-- round 3 E5-E9). Split out of tests/test_bar.lua by the smoke round 2 review
-- fixes, to keep that suite under the 1000-line file budget; it shares tests/bar_scene.lua.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local H = dofile(T.root .. "/tests/bar_scene.lua")(T)
local scene, complete, accessory, settle, point = H.scene, H.complete, H.accessory, H.settle, H.point

--- LibSharedMedia's path for font `key` in the mock, or nil.
local function fontPath(M, key)
    local LSM = M.LibStub("LibSharedMedia-3.0", true)
    return type(key) == "string" and LSM:Fetch("font", key, true) or nil
end

test("bar: a label draws through S.HudFont with its font block, and its color follows the skin until told not to", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    local S = NS.Skin
    local seen
    local realFont = S.HudFont
    S.HudFont = function(fs, opts) seen = opts; return realFont(fs, opts) end
    NS.SetByPath("bar.labels.fontSize", 14)
    -- A swatch unlike the skin's gold, so the color check below tells the two apart.
    NS.SetByPath("bar.labels.fontColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 })
    settle(M)
    S.HudFont = realFont
    -- red under: a label painted with a plain SetFont (skinning-§6: HUD text draws through S.HudFont)
    assertTrue(seen ~= nil, "S.HudFont was not called")
    assertEqual(seen.flags, "@skin", "the flags From skin")
    assertEqual(seen.size, S.HudFontSize(14, true), "the size through S.HudFontSize")
    assertEqual(seen.shadowFromSkin, true)
    assertEqual(seen.face, fontPath(M, S.Token("hud.font")), "the skin's face while Use the skin's font is on")
    local r, g, b = Bar.Label(1):GetTextColor()
    local sr, sg, sb = S.HudLabelColor()
    -- red under: labelColor drawing the swatch while fontColorFromSkin is on
    assertTrue(r == sr and g == sg and b == sb, "the skin's HUD label color")
    assertFalse(r == 0.1 and g == 0.2 and b == 0.3, "not the swatch")
    NS.SetByPath("bar.labels.fontColorFromSkin", false)
    settle(M)
    r, g, b = Bar.Label(1):GetTextColor()
    -- red under: the swatch never read (the label always in the skin's color)
    assertTrue(r == 0.1 and g == 0.2 and b == 0.3, "the swatch")
end)

test("bar: the player's plate and icon edge take the skin's border color while that companion stays on", function()
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    NS.SetByPath("bar.bgFromSkin", false)
    NS.SetByPath("bar.frame.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    NS.SetByPath("bar.icons.borderStyleFromSkin", false)
    NS.SetByPath("bar.icons.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    settle(M)
    assertEqual(NS.GetSetting("bar.frame.borderColorFromSkin"), true, "the default follows the skin")
    assertEqual(NS.GetSetting("bar.icons.borderColorFromSkin"), true, "the default follows the skin")
    local f = Bar.Frame()
    assertTrue(f.plate:IsShown(), "the player's plate")
    local function same(label, got, want)
        assertTrue(want[1] ~= nil, label .. ": the skin answers the token")
        assertTrue(got[1] == want[1] and got[2] == want[2] and got[3] == want[3], label .. ": the skin's color")
        assertFalse(got[1] == 1 and got[2] == 0 and got[3] == 0, label .. ": not the swatch")
    end
    -- red under: Bar.EdgeColor reading the swatch whatever borderColorFromSkin says
    same("plate", { f.plate:GetBackdropBorderColor() }, { NS.Skin.Color("bar.border") })
    local btn = Bar.Buttons()[1]
    assertTrue(btn.edge ~= nil and btn.edge:IsShown(), "the player's icon edge")
    same("icon", { btn.edge:GetBackdropBorderColor() }, { NS.Skin.Color("icon.border") })
end)

test("bar: without the library test mode reserves no strip room, and the header title says test mode", function()
    local inst = T.load({ libFiles = {} })
    local NS, M = inst.NS, inst.mocks
    dofile(T.root .. "/tests/_kit/mock_paint.lua")(M)
    H.recordGeometry(M)
    local on = true
    T.fake(NS, "Dock", { IsShown = function() return false end, AloneSpot = true, Suspend = true, Resume = true })
    local preview = T.fake(NS, "Preview", { IsActive = function() return on end, Suspend = true, Resume = true })
    rawset(preview, "Source", { Rows = function() return { { categoryID = "Complete", outfits = {
        { id = "preview:1", name = "Test Outfit 1", icon = 132276, placeholder = true } } } } end })
    NS.Bar.Resume()
    M.__fireTimers()
    local f = NS.Bar.Frame()
    assertTrue(f ~= nil and f:IsShown(), "test mode shows the bar")
    assertEqual(f.strip, false, "no strip without the library")
    local row = point(NS.Bar.Buttons()[1]:GetParent())
    -- red under: Render told a strip shows (HeaderHeight(true)) when MakeTestStrip answered nil
    assertEqual(row[5], -(NS.Bar.HeaderHeight() + NS.GetSetting("bar.layout.padding")), "no gap for a strip not drawn")
    -- red under: no marker at all (preview-mode: the header word stands where no strip shows)
    assertEqual(f.title:GetText(), "Outfits (test mode)")
    on = false
    NS.db.profile.bar.shown = true
    NS.Bar.Refresh()
    assertEqual(f.title:GetText(), "Outfits", "the live bar's title")
end)

test("bar: with Ignore fonts on a label draws its own stored face, the seam's answer", function()
    local NS, M = scene()
    complete(NS, "A")
    local S = NS.Skin
    local seen
    local realFont = S.HudFont
    S.HudFont = function(fs, opts) seen = opts; return realFont(fs, opts) end
    NS.SetByPath("skin.ignoreFonts", true)
    NS.SetByPath("bar.labels.fontSize", 13)
    settle(M)
    S.HudFont = realFont
    NS.SetByPath("skin.ignoreFonts", false)
    assertEqual(NS.GetSetting("bar.labels.fontFromSkin"), true, "Use the skin's font stays on")
    local want = fontPath(M, NS.GetSetting("bar.labels.font"))
    assertTrue(want ~= nil, "the stored face is registered")
    -- red under: a face resolved around S.Resolve (nil while it follows the skin, so the client's font)
    assertTrue(seen ~= nil, "S.HudFont was not called")
    assertEqual(seen.face, want, "the stored pick, as skinning-§6 has the seam answer it")
end)

test("bar: a button's edges, worn edge and worn mark stand on named rungs, the mark on a mouse-off overlay", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    NS.Stack.Wear(hat, { hw = true })
    NS.SetByPath("bar.icons.borderStyleFromSkin", false)
    settle(M)
    local LEVEL = NS.Constants.LAYERS.LEVEL
    -- frame-layering-§3: BORDER < the worn edge < OVERLAY, every rung named in LAYERS.LEVEL
    assertTrue(LEVEL.BAR_EDGE < LEVEL.BAR_WORN_EDGE and LEVEL.BAR_WORN_EDGE < LEVEL.BAR_OVERLAY, "the rung order")
    local btn = Bar.Buttons()[1]
    local base = btn:GetFrameLevel()
    assertTrue(btn.edge ~= nil and btn.wornEdge ~= nil and btn.overlay ~= nil, "the three child frames")
    -- red under: backdropFrame's bare 1 and 2, and the mark left on the button under its child frames
    assertEqual(btn.skinEdge:GetFrameLevel(), base + LEVEL.BAR_EDGE, "the skin's edge")
    assertEqual(btn.edge:GetFrameLevel(), base + LEVEL.BAR_EDGE, "the player's edge")
    assertEqual(btn.wornEdge:GetFrameLevel(), base + LEVEL.BAR_WORN_EDGE, "the worn edge")
    assertEqual(btn.overlay:GetFrameLevel(), base + LEVEL.BAR_OVERLAY, "the overlay")
    assertTrue(btn.worn:GetParent() == btn.overlay, "the worn mark on the overlay")
    assertEqual(rawget(btn.overlay, "__mouse"), false, "the overlay passes the mouse through")
    assertTrue(btn.worn:IsShown() and btn.wornEdge:IsShown(), "both show for a worn outfit")
end)

--- Whether the library drew a shown edge ring on `frame` (its record's holder and top edge).
local function libEdgeShown(Skin, frame)
    local rec = Skin.painted[frame]
    local h = rec and rec.regions.holder
    local top = rec and rec.regions.edgeTop
    return h ~= nil and h:IsShown() == true and top ~= nil and top:IsShown() == true
end

test("bar: Icons > Show border draws the skin's icon edge when on and no edge at all when off, in every skin", function()
    -- Smoke round 3 E5 (screens 21-23): S.SquareIcon on the button drew a second, permanent edge in
    -- the window outline (icon.outline) that Show border never reached, so off still showed a border
    -- (Ka0s Default's gray outline: on looked off) and on drew one over it (every other skin: no change).
    -- red under: modules/Bar_Buttons.lua's S.SquareIcon(btn, { crop = true }) back in NewButton.
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    settle(M)
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local keys = {}
    for _, def in ipairs(Skin:Skins()) do keys[#keys + 1] = def.key end
    assertTrue(#keys > 2, "too few shipped skins to switch through")
    for _, key in ipairs(keys) do
        NS.ApplySkinChoice("ka0s", key)
        for _, on in ipairs({ true, false }) do
            NS.SetByPath("bar.icons.borderShow", on)
            settle(M)
            local btn = Bar.Buttons()[1]
            local what = key .. (on and " on" or " off")
            assertFalse(libEdgeShown(Skin, btn), what .. ": an edge on the button outside the Border block")
            assertEqual(btn.skinEdge:IsShown() == true, on, what .. ": the skin's icon edge")
            assertTrue(libEdgeShown(Skin, btn.skinEdge), what .. ": the skin's edge is drawn on its frame")
        end
    end
    NS.ApplySkinChoice("ka0s", "ka0s")
    -- The art's own border stays trimmed without S.SquareIcon's crop.
    local c = { Bar.Buttons()[1].icon:GetTexCoord() }
    assertTrue(c[1] >= 0.07 and c[7] <= 0.93, "the icon is cropped")
end)

test("bar: Icons > Show border on draws the skin's window icon outline, which shows on the bar's dark background", function()
    -- Review of smoke round 3 E5: the bar always draws a window background (E6), and the HUD edge
    -- (`icon.border`, black under Ka0s Default) on it read as no border at all (screen 21). The
    -- edge is the window outline, `icon.outline`, which falls back to `icon.border` in a skin that
    -- states none.
    -- red under: modules/Bar_Buttons.lua's S.IconBorder(btn.skinEdge, { ..., hud = true, ... }).
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    NS.ApplySkinChoice("ka0s", "ka0s")
    NS.SetByPath("bar.icons.borderShow", true)
    settle(M)
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local rec = Skin.painted[Bar.Buttons()[1].skinEdge]
    local top = rec and rec.regions.edgeTop
    assertTrue(top ~= nil, "the skin's edge is drawn")
    local got, want = rawget(top, "__color"), NS.Skin.Token("icon.outline")
    assertTrue(type(want) == "table", "Ka0s Default states icon.outline")
    for i = 1, 3 do assertEqual(got[i], want[i], "the outline's channel " .. i) end
end)

test("bar: Frame > Show background is gone, and a stored false from round 2 hides nothing", function()
    -- Smoke round 3 E6 (screen 24): the row, its default and its reader are removed; the bar always
    -- draws one of its two background layers.
    -- red under: the bar.showBackground row, its default, or PaintChrome's read of it kept.
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    T.assertNil(NS.FindSchemaRow("bar.showBackground"), "the row is registered")
    T.assertNil(NS.defaults.profile.bar.showBackground, "the default is kept")
    NS.db.profile.bar.showBackground = false
    NS.SetByPath("bar.vertical", true)
    settle(M)
    local f = Bar.Frame()
    assertTrue(f.chrome:IsShown(), "the skin's chrome shows whatever a stale value says")
    NS.SetByPath("bar.bgFromSkin", false)
    settle(M)
    assertTrue(f.plate:IsShown(), "the player's plate shows whatever a stale value says")
end)

--- Whether the library's Shell drew an edge on `frame`: its flat top edge shown, or a nine-slice.
local function shellEdgeShown(Skin, frame)
    local rec = Skin.painted[frame]
    if not rec then return false end
    local top = rec.regions.edgeTop
    return (top ~= nil and top:IsShown() == true) or rec.regions.nine ~= nil
end

--- Every skin's key, in the library's order.
local function skinKeys(Skin)
    local keys = {}
    for _, def in ipairs(Skin:Skins()) do keys[#keys + 1] = def.key end
    return keys
end

--- Whether the applied skin's bar border is a real style (one that wins over Show border,
--- skinning-§6).
local function realStyle(NS)
    local style = NS.Skin.Token("bar.borderStyle")
    return style ~= nil and style ~= "None"
end

--- The skins the E7 cases walk must hold both kinds, or a case below proves half the rule.
local function assertBothKinds(NS, Skin)
    local seen = {}
    for _, key in ipairs(skinKeys(Skin)) do
        NS.ApplySkinChoice("ka0s", key)
        seen[realStyle(NS)] = true
    end
    NS.ApplySkinChoice("ka0s", "ka0s")
    assertFalse(realStyle(NS), "Ka0s Default's bar border style is None")
    NS.ApplySkinChoice("ka0s", "azeroth")
    assertTrue(realStyle(NS), "Azeroth states a real bar border style")
    NS.ApplySkinChoice("ka0s", "ka0s")
    assertTrue(seen[true] and seen[false], "the sweep covers None and a real style")
end

test("bar: Frame > Show border is dimmed only while Use the skin's border is on under a skin with a real border style", function()
    -- Smoke round 3 E7, the owner's ruling (follow the standard), skinning-§6: a skin's None bar
    -- border defers, so the switch stays live and the player's; a real style wins with the companion
    -- on, so the switch is dimmed, reads ticked and its tooltip says why; off, it is the player's in
    -- every skin. This is LibKa0s's composed BorderGroup rule (compose minor 18), kept as composed.
    -- red under: a host disabledIf/skinValue that dims it whenever the companion is on (Ka0s
    -- Default dimmed), or one that never dims it (a real style live), or the library's tooltip kept.
    local NS, M = scene()
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    assertBothKinds(NS, Skin)
    local row = NS.FindSchemaRow("bar.frame.borderShow")
    assertTrue(row.tooltip:find("Use the skin's border", 1, true) ~= nil, "the tooltip names the companion")
    assertTrue(row.tooltip:find("dimmed", 1, true) ~= nil, "the tooltip says when the switch is dimmed")
    assertTrue(row.tooltip:find("no border style", 1, true) ~= nil, "the tooltip says a None skin leaves it live")
    for _, key in ipairs(skinKeys(Skin)) do
        NS.ApplySkinChoice("ka0s", key)
        local real = realStyle(NS)
        NS.SetByPath("bar.frame.borderStyleFromSkin", true)
        assertEqual(row.disabledIf(row) == true, real, key .. ": dimmed exactly under a real style")
        if real then
            assertEqual(row.skinValue(row), true, key .. ": reads ticked under the skin's real style")
        else
            T.assertNil(row.skinValue(row), key .. ": the stored value shows under the skin's None")
        end
        NS.SetByPath("bar.frame.borderStyleFromSkin", false)
        assertFalse(row.disabledIf(row) == true, key .. ": live once the companion is off")
        T.assertNil(row.skinValue(row), key .. ": the stored value shows once the companion is off")
    end
    NS.ApplySkinChoice("ka0s", "ka0s")
end)

test("bar: Frame > Show border governs the edge but under a skin's real border style with Use the skin's border on", function()
    -- Smoke round 3 E7, skinning-§6. Both layers: the skin's chrome (Use the skin's background on,
    -- S.Shell's `noBorder`) and the player's plate (its backdrop edge), in every skin. Companion on
    -- under a None skin: on draws the edge (the plate in the player's style), off draws none.
    -- Companion on under a real style: the skin's edge whatever the switch says. Companion off: the
    -- switch, in every skin.
    -- red under: Bar.PaintChrome forcing the edge whenever the companion is on (None ignores off),
    -- or reading the switch ahead of S.BarBorder (a real style hidden by off).
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    settle(M)
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local f = Bar.Frame()
    for _, key in ipairs(skinKeys(Skin)) do
        NS.ApplySkinChoice("ka0s", key)
        local real = realStyle(NS)
        for _, follow in ipairs({ true, false }) do
            NS.SetByPath("bar.frame.borderStyleFromSkin", follow)
            for _, on in ipairs({ false, true }) do
                local tag = key .. (follow and " following" or " own") .. (on and ": on" or ": off")
                local want = (follow and real) or on
                NS.SetByPath("bar.frame.borderShow", on)
                NS.SetByPath("bar.bgFromSkin", true)
                settle(M)
                assertTrue(f.chrome:IsShown(), tag .. ": the skin's chrome")
                if NS.Skin.Token("win.border") ~= nil then
                    assertEqual(shellEdgeShown(Skin, f.chrome), want, tag .. ": the chrome's edge")
                end
                NS.SetByPath("bar.bgFromSkin", false)
                settle(M)
                assertTrue(f.plate:IsShown(), tag .. ": the player's plate")
                local edge = f.plate:GetBackdrop().edgeFile
                assertEqual(edge ~= nil, want, tag .. ": the plate's edge")
                if want then
                    local style = (follow and real) and NS.Skin.Token("bar.borderStyle") or "Solid"
                    assertEqual(edge, Bar.BorderFile(style), tag .. ": the plate's edge style")
                end
            end
        end
    end
    NS.ApplySkinChoice("ka0s", "ka0s")
end)

test("bar: a skin switch moves Frame > Show border's dimming and the edge between a None skin and a real style", function()
    -- Smoke round 3 E7, skinning-§6, and the smoke row's last step (R3B3). With the companion on and
    -- Show border off, Ka0s Default (None) draws no edge and leaves the row live; Azeroth (Solid)
    -- draws its edge and dims the row; back again, both undo. With the companion off, off stays off
    -- across every switch, which only S.Shell's replay of the recorded `noBorder` keeps
    -- (PaintChrome calls it only when the answer moves).
    -- red under: an answer computed once and kept across a skin switch, or a skin switch re-dressing
    -- the chrome without that opt.
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local row = NS.FindSchemaRow("bar.frame.borderShow")
    local f = Bar.Frame()
    NS.SetByPath("bar.frame.borderStyleFromSkin", true)
    NS.SetByPath("bar.frame.borderShow", false)
    for _, bg in ipairs({ true, false }) do
        NS.SetByPath("bar.bgFromSkin", bg)
        for _, key in ipairs({ "ka0s", "azeroth", "ka0s" }) do
            local tag = key .. (bg and " chrome" or " plate")
            NS.ApplySkinChoice("ka0s", key)
            settle(M)
            local real = key == "azeroth"
            assertEqual(row.disabledIf(row) == true, real, tag .. ": the row's dimming")
            if bg then
                assertEqual(shellEdgeShown(Skin, f.chrome), real, tag .. ": the chrome's edge")
            else
                assertEqual(f.plate:GetBackdrop().edgeFile ~= nil, real, tag .. ": the plate's edge")
            end
        end
    end
    NS.SetByPath("bar.frame.borderStyleFromSkin", false)
    NS.SetByPath("bar.bgFromSkin", true)
    settle(M)
    for _, key in ipairs(skinKeys(Skin)) do
        NS.ApplySkinChoice("ka0s", key)
        settle(M)
        assertFalse(row.disabledIf(row) == true, key .. ": live with the companion off")
        if NS.Skin.Token("win.border") ~= nil then
            assertFalse(shellEdgeShown(Skin, f.chrome), key .. ": the edge stays off across the switch")
        end
    end
    NS.ApplySkinChoice("ka0s", "ka0s")
end)

-- ── the layout mode (smoke round 3 E9) ───────────────────────────────────────────────────────────

test("bar: the Layout tab's Grouping row is Grouped or Collapsed, and Collapsed hides every label row", function()
    -- options-ui-§22: a group of rows only one value of a mode selector uses is hidden, not dimmed,
    -- while another value is picked; the Labels tab then shows one note naming the selector.
    -- red under: no bar.layout.mode row, or a label row without its shownWhen on Grouped.
    local NS = scene()
    local row = NS.FindSchemaRow("bar.layout.mode")
    assertTrue(row ~= nil, "no bar.layout.mode row")
    assertEqual(row.group, "Layout")
    assertEqual(row.default, "grouped")
    assertEqual(NS.GetSetting("bar.layout.mode"), "grouped")
    assertEqual(row.values.grouped, "Grouped")
    assertEqual(row.values.collapsed, "Collapsed")
    assertTrue(row.tooltip:find("Grouped", 1, true) ~= nil and row.tooltip:find("Collapsed", 1, true) ~= nil,
        "the tooltip explains both")
    local function dims(path) local r = NS.FindSchemaRow(path); return r.disabledIf ~= nil and r.disabledIf() == true end
    NS.db.profile.bar.labels.fontFromSkin = false
    local LABELS = { "bar.labels.show", "bar.labels.font", "bar.labels.fontSize", "bar.labels.fontFlags",
                     "bar.labels.fontShadow", "bar.labels.useClassColorFont", "bar.labels.fontFromSkin",
                     "bar.labels.fontColor", "bar.labels.fontColorFromSkin", "bar.labels.fontShadowFromSkin" }
    for _, path in ipairs(LABELS) do
        local sw = NS.FindSchemaRow(path).shownWhen
        assertTrue(type(sw) == "table" and sw.path == "bar.layout.mode" and sw.equals == "grouped",
            path .. " is shown only while Grouped")
    end
    -- The note that stands in for them: shown only while Collapsed, and naming the selector.
    local note
    for _, r in ipairs(NS.Schema) do
        if r.type == "note" and r.group == "Labels" and r.page == row.page then note = r end
    end
    assertTrue(note ~= nil, "the Labels tab's note")
    assertTrue(note.shownWhen ~= nil and note.shownWhen.path == "bar.layout.mode"
        and note.shownWhen.equals == "collapsed", "the note shows only while Collapsed")
    assertTrue(note.text:find("Grouping", 1, true) ~= nil, "the note names the Grouping row")
    -- Hidden is not disabled: Collapsed no longer dims them; the labels switch still does.
    NS.SetByPath("bar.layout.mode", "collapsed")
    assertFalse(dims("bar.labels.show"), "Collapsed: the labels switch is not dimmed")
    assertFalse(dims("bar.labels.fontSize"), "Collapsed: the size is not dimmed")
    NS.SetByPath("bar.labels.show", false)
    assertTrue(dims("bar.labels.fontSize"), "the font rows still dim while the labels are off")
    T.assertNil(NS.FindSchemaRow("bar.labels.fontColor").disabledIf, "the swatch is never grayed")
end)

test("bar: Collapsed draws every shown outfit as one group with no labels; Grouped keeps a row per category", function()
    -- red under: Bar.Render laying out one block per category whatever bar.layout.mode says.
    local NS, M, Bar = scene()
    complete(NS, "A"); accessory(NS, "B")
    NS.db.profile.windows.bar = { point = "TOPLEFT", x = 0, y = 0 }
    settle(M)
    local P = NS.GetSetting("bar.layout.padding")
    local _, y1 = H.at(Bar.Buttons()[1])
    local _, y2 = H.at(Bar.Buttons()[2])
    assertTrue(y1 ~= y2, "Grouped: two rows")
    assertTrue(Bar.Label(1):IsShown(), "Grouped: the labels show")
    NS.SetByPath("bar.layout.mode", "collapsed")
    settle(M)
    local btns = Bar.Buttons()
    assertEqual(#btns, 2, "every outfit still drawn")
    _, y1 = H.at(btns[1])
    _, y2 = H.at(btns[2])
    assertEqual(y1, y2, "Collapsed: one line")
    assertEqual(y1, Bar.HeaderHeight() + P, "no label line above it")
    assertEqual(Bar.LabelHeight(), 0, "no label height")
    -- A label is its row frame's child: the second row frame hides with no outfits of its own.
    local function visible(fs) return fs:IsShown() == true and fs:GetParent():IsShown() == true end
    assertFalse(visible(Bar.Label(1)) or visible(Bar.Label(2)), "no label shows")
    assertTrue(btns[1].outfit.category == "Complete" and btns[2].outfit.category == "Accessory",
        "the categories in display order")
end)
