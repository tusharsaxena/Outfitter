-- tests/test_bar.lua — P4.20 (design §7.7, INV §7.6): modules/Bar.lua's container, layout, show
-- decision, alpha, fades, position and lifecycle, and modules/Bar_Buttons.lua's icon ladder, clicks,
-- drops and tooltip.
--
-- NS.Preview and NS.Dock run against recorded fakes (design §12, the fake rule), so a case sets test
-- mode and the window's state itself; NS.OutfitMenu is the real menu under a recorder (tests/spy.lua,
-- its fake retired at P4.27). Outfits, Stack, Equip, Inventory, Triggers and OutfitTooltip are
-- the real modules, and the items move for real in tests/mock_gear.lua. The bar's frames are built
-- lazily, so the kit's paint and layer recorders and the scene's geometry recorder
-- (tests/bar_scene.lua) are installed after the load and still see every frame the bar makes. Since
-- smoke round 2 (design G6) it also pins the layout, the header, the labels, the icon edge and the
-- worn highlight.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local H = dofile(T.root .. "/tests/bar_scene.lua")(T)
local geom, naked, scene, complete, accessory = H.geom, H.naked, H.scene, H.complete, H.accessory
local ids, settle, buttonFor, point, at = H.ids, H.settle, H.buttonFor, H.point, H.at

-- ── the surface and the default ───────────────────────────────────────────────────────────────

test("bar: NS.Bar is published with the §7.7 surface", function()
    local Bar = T.NS.Bar
    assertEqual(type(Bar), "table")
    for _, k in ipairs({ "Render", "Refresh", "ApplyScale", "ApplyAlpha", "SetLocked", "SavePosition",
                         "OutfitIcon", "Suspend", "Resume", "Buttons", "Frame",
                         "NewButton", "SetButton", "Drop", "ShouldShow" }) do
        assertEqual(type(Bar[k]), "function", k)
    end
    -- The reset is the `bar.position` row's (NS.ApplyDefault), so the bar carries no second writer.
    assertEqual(Bar.ResetPosition, nil, "Bar.ResetPosition writes profile.windows.bar around the seam")
    assertEqual(type(Bar.LiveSource.Rows), "function")
end)

test("bar: bar.shown defaults false, so a fresh profile and a repaired one both come up hidden", function()
    local NS, _, Bar = scene({ hidden = true })
    -- red under: a `bar.shown = true` default in defaults/Profile.lua (the legacy fresh-install split)
    assertEqual(NS.defaults.profile.bar.shown, false)
    assertEqual(NS.GetSetting("bar.shown"), false)
    complete(NS, "Normal")
    assertFalse(Bar.ShouldShow())
    assertFalse(Bar.Refresh(), "nothing to show")
    assertTrue(Bar.Frame() == nil or not Bar.Frame():IsShown(), "the bar stayed hidden")
end)

test("bar: the container sits in the HUD strata, movable, clamped and toplevel; rows and buttons in their bands", function()
    local NS, M, Bar = scene()
    complete(NS, "Normal")
    settle(M)
    local f = Bar.Frame()
    local layers = M.__layers(f)
    assertEqual(layers.strata, NS.Constants.LAYERS.STRATA.HUD)
    assertTrue(layers.clamped, "clamped")
    assertTrue(layers.toplevel, "toplevel")
    local btn = Bar.Buttons()[1]
    assertEqual(btn:GetFrameLevel(), f:GetFrameLevel() + NS.Constants.LAYERS.LEVEL.BAR_BUTTON)
    assertTrue(f:IsShown())
end)

-- ── what is on it ─────────────────────────────────────────────────────────────────────────────

test("bar: one button per visible outfit, a row per category, and a re-render never grows the pool", function()
    local NS, M, Bar = scene()
    local a, b = complete(NS, "Normal"), complete(NS, "Naked")
    local hat, hood = accessory(NS, "Hat"), accessory(NS, "Hood")
    local hidden = accessory(NS, "Hidden")
    NS.SetByPath("outfit.bar.hide", true, hidden)
    settle(M)
    assertEqual(ids(Bar), table.concat({ a, b, hat, hood }, ","))
    for _ = 1, 3 do Bar.Refresh() end
    -- red under: an extra acquire per row (the legacy _ButtonBar's extra button)
    assertEqual(#Bar.Buttons(), 4)
    NS.SetByPath("outfit.bar.hide", false, hidden)
    settle(M)
    assertEqual(#Bar.Buttons(), 5, "bar.hide cleared puts it back")
end)

test("bar: an outfit whose trigger is off is not on the bar, and a manual wear of it puts it back", function()
    local NS, M, Bar = scene()
    local o = accessory(NS, "Dungeon")
    NS.SetByPath("outfit.trigger.id", "IN_DUNGEON", o)
    NS.SetByPath("outfit.trigger.disabled", true, o)
    settle(M)
    -- red under: a LiveSource that ignores trigger.disabled
    assertEqual(ids(Bar), "")
    -- the window's left-click wear (design §5.8: a manual wear clears the Disabled flag)
    NS.Stack.Wear(o, { hw = true, clearDisabled = true })
    settle(M)
    assertFalse(NS.Outfits.Get(o).trigger.disabled == true)
    assertEqual(ids(Bar), o)
    assertTrue(Bar.Buttons()[1].worn:IsShown(), "worn mark on")
end)

-- ── layout ────────────────────────────────────────────────────────────────────────────────────

test("bar: the layout's defaults are 4 px between icons and 8 px in from the edge", function()
    local Layout = T.NS.Bar.Layout
    local D = T.NS.defaults.profile.bar
    -- red under: the round 2 defaults (spacing 5, the legacy 37 px pitch; padding 4); smoke round 3 E8
    assertEqual(D.layout.spacing, 4)
    assertEqual(D.layout.padding, 8)
    assertEqual(D.layout.perLine, 0)
    local g = Layout.Compute({ size = 32, spacing = 5, padding = 4, perLine = 0, counts = { 3, 1 },
                               gx = 1, gy = -1 })
    assertEqual(g.width, 4 + 3 * 32 + 2 * 5 + 4)
    assertEqual(g.height, 4 + 32 + 5 + 32 + 4)
    local a, b = g.blocks[1].icons[1], g.blocks[1].icons[2]
    assertEqual(a.x, 4); assertEqual(a.y, 4)
    assertEqual(b.x - a.x, 37, "the pitch along the row")
    assertEqual(g.blocks[2].icons[1].y - a.y, 37, "the pitch between the rows")
end)

test("bar: a spacing or padding that is no number lays out at the defaults", function()
    -- red under: Bar.LayoutSpec's own fallbacks kept at the round 2 values (spacing 5, padding 4)
    local NS, _, Bar = scene()
    NS.db.profile.bar.layout.spacing = "wide"
    NS.db.profile.bar.layout.padding = "wide"
    local spec = Bar.LayoutSpec({ 1 })
    assertEqual(spec.spacing, NS.defaults.profile.bar.layout.spacing)
    assertEqual(spec.padding, NS.defaults.profile.bar.layout.padding)
end)

test("bar: the layout wraps at icons per line, in rows or in columns", function()
    local Layout = T.NS.Bar.Layout
    local g = Layout.Compute({ size = 20, spacing = 2, padding = 0, perLine = 2, counts = { 5 }, gx = 1, gy = -1 })
    -- red under: a perLine read as the number of lines
    assertEqual(g.width, 2 * 20 + 2); assertEqual(g.height, 3 * 20 + 2 * 2)
    local i = g.blocks[1].icons
    assertEqual(i[3].x, 0); assertEqual(i[3].y, 22, "the third icon opens the second row")
    assertEqual(i[5].y, 44)
    local v = Layout.Compute({ size = 20, spacing = 2, padding = 0, perLine = 2, counts = { 5 }, vertical = true,
                               gx = 1, gy = -1 })
    assertEqual(v.width, 3 * 20 + 2 * 2); assertEqual(v.height, 2 * 20 + 2)
    assertEqual(v.blocks[1].icons[2].y, 22, "down the column first")
    assertEqual(v.blocks[1].icons[3].x, 22, "then the next column")
    local none = Layout.Compute({ size = 20, spacing = 2, padding = 0, perLine = 0, counts = { 5 }, gx = 1, gy = -1 })
    assertEqual(none.height, 20, "0 is one line")
end)

test("bar: the layout grows away from its corner, the first icon and block at that corner", function()
    local Layout = T.NS.Bar.Layout
    local base = { size = 10, spacing = 0, padding = 1, perLine = 0, counts = { 2, 1 }, top = 7 }
    local function g(gx, gy, vertical)
        local s = {}
        for k, v in pairs(base) do s[k] = v end
        s.gx, s.gy, s.vertical = gx, gy, vertical
        return Layout.Compute(s)
    end
    local left = g(-1, -1)
    -- red under: an x grown from the left edge whatever gx says
    assertEqual(left.blocks[1].icons[1].x, 11, "growing left, the first icon is at the right")
    assertEqual(left.blocks[1].icons[2].x, 1)
    assertEqual(left.blocks[2].icons[1].x, 11, "a shorter row is right-aligned")
    local up = g(1, 1)
    assertEqual(up.blocks[1].icons[1].y, 7 + 1 + 10, "growing up, the first row is at the bottom")
    assertEqual(up.blocks[2].icons[1].y, 7 + 1)
    local down = g(1, -1)
    assertEqual(down.blocks[1].icons[1].y, 7 + 1, "the header's height is above the first row")
    local vleft = g(-1, -1, true)
    assertEqual(vleft.blocks[1].x, vleft.blocks[2].x + 10, "vertical and growing left, the first column is right")
    local vup = g(1, 1, true)
    -- red under: a vertical block placed at the top whatever gy says
    assertEqual(vup.blocks[2].icons[1].y, vup.blocks[1].icons[1].y, "growing up, a shorter column is bottom-aligned")
    assertEqual(vup.blocks[2].icons[1].y, 7 + 1 + 10)
end)

test("bar: the layout adds each block's label line and never draws narrower than its minimum", function()
    local Layout = T.NS.Bar.Layout
    local g = Layout.Compute({ size = 10, spacing = 2, padding = 3, counts = { 1, 1 }, labelH = 12, minWidth = 100,
                               gx = 1, gy = -1 })
    assertEqual(g.width, 100)
    assertEqual(g.height, 3 + 12 + 10 + 2 + 12 + 10 + 3)
    local b = g.blocks[1]
    assertEqual(b.icons[1].y, 3 + 12, "the icons sit under the label")
    assertEqual(b.label.y, 3); assertEqual(b.label.x, 3)
    assertEqual(b.label.w, 100 - 2 * 3, "a row's label spans the bar")
    local v = Layout.Compute({ size = 10, spacing = 2, padding = 3, counts = { 1 }, labelH = 12, vertical = true,
                               gx = 1, gy = -1 })
    assertEqual(v.blocks[1].label.w, 10, "a column's label is the column's width (truncated)")
end)

test("bar: Render places the buttons from the layout settings and sizes the bar", function()
    local NS, M, Bar = scene()
    complete(NS, "A"); complete(NS, "B"); complete(NS, "C"); accessory(NS, "D")
    NS.db.profile.windows.bar = { point = "TOPLEFT", x = 0, y = 0 }
    NS.SetByPath("bar.layout.padding", 6)
    NS.SetByPath("bar.layout.spacing", 3)
    NS.SetByPath("bar.icons.size", 20)
    settle(M)
    local f, btns = Bar.Frame(), Bar.Buttons()
    local top, lh = Bar.HeaderHeight(), Bar.LabelHeight()
    local x1, y1 = at(btns[1])
    assertEqual(x1, 6); assertEqual(y1, top + 6 + lh)
    local x2 = at(btns[2])
    -- red under: Render keeping the fixed 37 px PITCH
    assertEqual(x2 - x1, 23)
    assertEqual(btns[1].__w, 20, "the icon size")
    local _, y4 = at(btns[4])
    assertEqual(y4 - y1, 23 + lh, "the second category's row, under its own label")
    local g = Bar.Layout.Compute(Bar.LayoutSpec({ 3, 1 }))
    assertEqual(f.__w, g.width); assertEqual(f.__h, g.height)
    NS.SetByPath("bar.layout.perLine", 2)
    settle(M)
    btns = Bar.Buttons()
    local x3, y3 = at(btns[3])
    assertEqual(x3, 6); assertEqual(y3 - y1, 23, "wrapped onto a second row")
end)

test("bar: with grow direction auto the buttons grow away from the saved corner, per quadrant", function()
    local NS, _, Bar = scene()
    complete(NS, "A"); complete(NS, "B"); accessory(NS, "C")
    local want = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 } }
    for corner, sign in pairs(want) do
        for _, vertical in ipairs({ false, true }) do
            NS.db.profile.windows.bar = { point = corner, x = 0, y = 0 }
            NS.db.profile.bar.vertical = vertical
            Bar.Refresh()
            local btns = Bar.Buttons()
            local x1, y1 = at(btns[1])
            local x2, y2 = at(btns[2])
            local x3, y3 = at(btns[3])
            -- red under: a QUADRANT row with a flipped sign
            if vertical then
                assertEqual(x2, x1, corner .. " vertical: one column")
                assertEqual((y2 - y1) * -sign[2] > 0, true, corner .. " vertical: down the column away from the corner")
                assertEqual((x3 - x1) * sign[1] > 0, true, corner .. " the second column away from the corner")
            else
                assertEqual(y2, y1, corner .. " horizontal: one row")
                assertEqual((x2 - x1) * sign[1] > 0, true, corner .. " along the row away from the corner")
                assertEqual((y3 - y1) * -sign[2] > 0, true, corner .. " the second row away from the corner")
            end
            local bar = point(Bar.Frame())
            assertEqual(bar[1], corner); assertEqual(bar[3], corner)
        end
    end
end)

test("bar: an explicit grow direction lays out by it and the drag stop saves the corner it implies", function()
    local NS, M, Bar = scene()
    complete(NS, "A"); complete(NS, "B")
    NS.SetByPath("bar.layout.growH", "left")
    NS.SetByPath("bar.layout.growV", "up")
    settle(M)
    local btns = Bar.Buttons()
    assertTrue(at(btns[1]) > at(btns[2]), "growing left")
    local f = Bar.Frame()
    geom(M.UIParent, 0, 1000, 800, 0)
    geom(f, 10, 60, 790, 740)   -- nearest TOPLEFT, but the grow says BOTTOMRIGHT
    -- red under: SavePosition saving the nearest corner whatever the grow direction says
    local p = Bar.SavePosition()
    assertEqual(p.point, "BOTTOMRIGHT")
    assertEqual(p.x, 60 - 1000); assertEqual(p.y, 740)
    NS.SetByPath("bar.layout.growH", "auto")
    NS.SetByPath("bar.layout.growV", "down")
    settle(M)
    p = Bar.SavePosition()
    -- red under: an auto horizontal taken as the explicit vertical's side
    assertEqual(p.point, "TOPLEFT", "auto keeps the nearest side, down pins the top")
end)

test("bar: changing the grow direction re-saves the place at the corner it implies, so the bar does not jump", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    geom(M.UIParent, 0, 1000, 800, 0)
    geom(f, 10, 60, 790, 740)
    NS.SetByPath("bar.layout.growH", "left")
    settle(M)
    -- red under: no SavePosition on a grow-direction write (the stored TOPLEFT would keep growing right)
    assertEqual(NS.db.profile.windows.bar.point, "TOPRIGHT")
    assertEqual(NS.db.profile.windows.bar.x, 60 - 1000)
end)

test("bar: a place written behind an explicit grow direction is re-saved at its corner on the next draw", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    geom(M.UIParent, 0, 1000, 800, 0)
    geom(f, 10, 60, 790, 740)
    NS.SetByPath("bar.layout.growH", "left")
    settle(M)
    -- Reset position writes the default TOPLEFT under a bar told to grow left.
    assertTrue(NS.ApplyDefault(NS.FindSchemaRow("bar.position")))
    settle(M)
    -- red under: a Refresh that anchors the stored TOPLEFT as it is (the bar grows right)
    assertEqual(NS.db.profile.windows.bar.point, "TOPRIGHT")
    assertEqual(point(f)[1], "TOPRIGHT")
end)

test("bar: the scale follows the Master row and divides the offset", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    NS.SetByPath("scale", 1.5)
    settle(M)
    assertEqual(f.__scale, 1.5)
    local p = point(f)
    assertEqual(p[4], 200 / 1.5, "the offset is divided by the effective scale")
end)

test("bar: the window look: the skin's Shell while it follows the skin, the player's plate when not", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    assertTrue(f.chrome:IsShown(), "the chrome shows")
    assertFalse(f.plate:IsShown(), "the plate waits")
    NS.SetByPath("bar.bgFromSkin", false)
    NS.SetByPath("bar.bgColor", { r = 0.2, g = 0.3, b = 0.4, a = 0.5 })
    NS.SetByPath("bar.frame.borderColorFromSkin", false)
    NS.SetByPath("bar.frame.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    NS.SetByPath("bar.frame.borderSize", 3)
    settle(M)
    -- red under: a single layer repainted (the Shell would replay the skin's colors over the player's)
    assertFalse(f.chrome:IsShown(), "the chrome hides")
    assertTrue(f.plate:IsShown(), "the plate shows")
    local r, g, b, a = f.plate:GetBackdropColor()
    assertTrue(r == 0.2 and g == 0.3 and b == 0.4 and a == 0.5, "the background swatch")
    local bd = f.plate:GetBackdrop()
    assertEqual(bd.edgeSize, 3, "the border thickness")
    r, g, b = f.plate:GetBackdropBorderColor()
    assertTrue(r == 1 and g == 0 and b == 0, "the border swatch")
    -- Show border governs once Use the skin's border is off, in every skin (skinning-§6, smoke round 3 E7).
    NS.SetByPath("bar.frame.borderStyleFromSkin", false)
    NS.SetByPath("bar.frame.borderShow", false)
    settle(M)
    assertNil(f.plate:GetBackdrop().edgeFile, "Show border off draws no edge")
end)

test("bar: the header band is titled Outfits, carries close and lock, and the icons sit under it", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    -- red under: the retired drag handle still built above the bar
    assertNil(f.handle, "the separate drag handle is retired")
    assertEqual(f.title:GetText(), "Outfits")
    assertTrue(f.close ~= nil and f.lock ~= nil and f.drag ~= nil, "close, lock and the drag strip")
    local inset, h = Bar.BandGeometry()
    assertEqual(Bar.HeaderHeight(), inset + h)
    assertTrue(Bar.HeaderHeight() >= 20, "a real band")
    local _, y = at(Bar.Buttons()[1])
    assertEqual(y, Bar.HeaderHeight() + NS.GetSetting("bar.layout.padding") + Bar.LabelHeight(),
        "the icons start under the band and the first label")
    assertTrue(f.__w >= Bar.Layout.MIN_WIDTH, "wide enough for the header")
    -- The drag strip stands on the band, left of the controls.
    local dp = point(f.drag)
    assertTrue(dp[2] == Bar.Band(), "the drag strip is anchored to the band")
end)

test("bar: the header's lock writes the Master lock and its close writes bar.shown off", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path) seen[#seen + 1] = path end)
    f.lock:__fire("OnClick")
    -- red under: a lock control that keeps a lock of its own (options-ui-§15's second switch)
    assertEqual(NS.db.profile.locked, true)
    assertEqual(table.concat(seen, ","), "locked", "through the seam")
    assertEqual(f.lock.icon:GetTexture(), NS.Icon("lock"))
    f.lock:__fire("OnClick")
    assertEqual(NS.db.profile.locked, false)
    assertEqual(f.lock.icon:GetTexture(), NS.Icon("unlock"))
    f.close:__fire("OnClick")
    settle(M)
    assertEqual(NS.db.profile.bar.shown, false, "close writes bar.shown")
    assertFalse(f:IsShown())
end)

test("bar: the header's right click opens the bar's settings page", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local opened = {}
    local real = NS.OpenOptionsPanel
    NS.OpenOptionsPanel = function(page) opened[#opened + 1] = page end
    Bar.Frame().drag:__fire("OnMouseUp", "RightButton")
    Bar.Frame().drag:__fire("OnMouseUp", "LeftButton")
    NS.OpenOptionsPanel = real
    assertEqual(table.concat(opened, ","), "bar")
end)

test("bar: without the library the header stands on a host band, title and lock included", function()
    local inst = T.load({ libFiles = {} })
    local NS, M = inst.NS, inst.mocks
    dofile(T.root .. "/tests/_kit/mock_paint.lua")(M)
    NS.db.profile.bar.shown = true
    NS.Outfits.Create("A", naked())
    NS.Bar.Resume()
    M.__fireTimers()
    local f = NS.Bar.Frame()
    assertTrue(f ~= nil and f:IsShown(), "the bar shows")
    -- red under: a header anchored to S.Band alone (nil without the library: nothing laid)
    local band = NS.Bar.Band()
    assertTrue(band ~= nil and band == f.hostBand, "the host's band")
    assertEqual(f.title:GetText(), "Outfits")
    assertTrue(f.lock ~= nil, "the lock control")
    assertEqual(NS.Bar.HeaderHeight(), 1 + 30)
end)

test("bar: each category's row carries its label above it, and the labels switch off", function()
    local NS, M, Bar = scene()
    complete(NS, "A"); accessory(NS, "B")
    NS.db.profile.windows.bar = { point = "TOPLEFT", x = 0, y = 0 }
    settle(M)
    local l1, l2 = Bar.Label(1), Bar.Label(2)
    assertTrue(l1:IsShown() and l2:IsShown(), "both labels show")
    assertEqual(l1:GetText(), "Complete outfits")
    assertEqual(l2:GetText(), "Accessories")
    local lh = Bar.LabelHeight()
    assertTrue(lh > 0, "a label line")
    local P = NS.GetSetting("bar.layout.padding")
    local _, y1 = at(Bar.Buttons()[1])
    -- red under: a label laid over the icons (no labelH in the layout spec)
    assertEqual(y1, Bar.HeaderHeight() + P + lh, "the row's icons under its label")
    local _, rel, _, _, ly = l1:GetPoint(1)
    assertTrue(rel == Bar.Frame(), "anchored to the bar")
    assertEqual(-ly, Bar.HeaderHeight() + P, "the label at the block's top")
    NS.SetByPath("bar.labels.show", false)
    settle(M)
    assertFalse(l1:IsShown(), "off: no label")
    assertEqual(Bar.LabelHeight(), 0)
    _, y1 = at(Bar.Buttons()[1])
    assertEqual(y1, Bar.HeaderHeight() + P, "off: no label line")
end)

test("bar: a vertical layout's label is as wide as its column", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    NS.SetByPath("bar.vertical", true)
    settle(M)
    -- red under: a vertical label spanning the whole bar over the next column
    assertEqual(Bar.Label(1):GetWidth(), NS.GetSetting("bar.icons.size"))
end)

-- ── position ─-- ── position ──────────────────────────────────────────────────────────────────────────────────

test("bar: the header's drag stop saves the nearest corner; a locked bar does not move", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    geom(M.UIParent, 0, 1000, 800, 0)
    geom(f, 900, 950, 100, 50)
    local drag = f.drag
    assertTrue(drag ~= nil, "the header's drag strip was built")
    drag:__fire("OnDragStart")
    drag:__fire("OnDragStop")
    local p = NS.db.profile.windows.bar
    assertEqual(p.point, "BOTTOMRIGHT"); assertEqual(p.x, -50); assertEqual(p.y, 50)
    geom(f, 10, 60, 790, 740)
    assertEqual(Bar.SavePosition().point, "TOPLEFT")
    assertEqual(NS.db.profile.windows.bar.y, -10)
    NS.SetByPath("locked", true)
    settle(M)
    geom(f, 900, 950, 100, 50)
    local moved = 0
    rawset(f, "StartMoving", function() moved = moved + 1 end)
    drag:__fire("OnDragStart")
    -- red under: an OnDragStart that ignores the lock
    assertEqual(moved, 0, "a locked bar does not start moving")
end)

test("bar: the drag stop writes bar.position through the seam, and its echo leaves the bar where it fell", function()
    -- red under: write `NS.db.profile.windows.bar = p` directly in Bar.SavePosition (modules/Bar.lua):
    -- a row's storage written around NS.SetByPath broadcasts no SETTINGS_CHANGED (architecture-§5)
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path) seen[#seen + 1] = path end)
    local f = Bar.Frame()
    geom(M.UIParent, 0, 1000, 800, 0)
    geom(f, 900, 950, 100, 50)
    f.drag:__fire("OnDragStart")
    f.drag:__fire("OnDragStop")
    assertEqual(table.concat(seen, ","), "bar.position", "the drag stop did not write through the seam")
    assertEqual(NS.GetSetting("bar.position"), "BOTTOMRIGHT -50 50")
    -- The echo schedules one redraw; it anchors at the corner just saved, not back at the old one.
    settle(M)
    local pt = point(Bar.Frame())
    assertEqual(pt[1], "BOTTOMRIGHT"); assertEqual(pt[4], -50); assertEqual(pt[5], 50)
    assertEqual(NS.GetSetting("bar.position"), "BOTTOMRIGHT -50 50", "the redraw wrote the position again")
end)

test("bar: the reset copies the default, so a drag after it never writes the default", function()
    local NS, M = scene()
    complete(NS, "A")
    settle(M)
    NS.db.profile.windows.bar = { point = "BOTTOMRIGHT", x = -5, y = 5 }
    -- The production reset (General > Master controls > Reset position, settings/General.lua).
    assertTrue(NS.ApplyDefault(NS.FindSchemaRow("bar.position")))
    local p, d = NS.db.profile.windows.bar, NS.defaults.profile.windows.bar
    assertEqual(p.point, d.point); assertEqual(p.x, d.x); assertEqual(p.y, d.y)
    -- red under: `NS.db.profile.windows.bar = d` (the legacy alias, OutfitterBar.lua:107-115)
    assertFalse(p == d, "a copy, not the default itself")
    p.x = 999
    assertEqual(d.x, 200, "the default is untouched")
end)

-- ── the icon ladder ───────────────────────────────────────────────────────────────────────────

test("bar: the icon ladder: own, the trigger's descriptor, the Birthday Suit, a single item, the default", function()
    local NS, M, Bar = scene()
    local O = NS.Outfits
    local own = accessory(NS, "Own")
    NS.SetByPath("outfit.icon", 134400 + 1, own)
    assertEqual(Bar.OutfitIcon(O.Get(own)), 134401)
    local solo = accessory(NS, "Solo")
    local DEFAULT = 132724   -- smoke round 2 design G1: NS.Constants.DEFAULT_OUTFIT_ICON
    assertEqual(NS.Constants.DEFAULT_OUTFIT_ICON, DEFAULT)
    -- red under: a name-keyed ladder (the legacy `Solo` key): the name alone draws the default icon
    assertEqual(Bar.OutfitIcon(O.Get(solo)), DEFAULT)
    NS.SetByPath("outfit.trigger.id", "INSTANCE_DIFFICULTY", solo)
    assertEqual(Bar.OutfitIcon(O.Get(solo)), 132132, "INSTANCE_DIFFICULTY's icon replaces Solo")
    local dungeon = accessory(NS, "Dungeon")
    NS.SetByPath("outfit.trigger.id", "IN_DUNGEON", dungeon)
    assertEqual(Bar.OutfitIcon(O.Get(dungeon)), DEFAULT, "a descriptor with no icon falls through")
    local nakedRec = O.Get(complete(NS, "Birthday"))
    nakedRec.builtin = "NAKED"
    assertEqual(Bar.OutfitIcon(nakedRec), Bar.NAKED_ICON)
    local info = NS.ItemInfo.FromBag(0, 5)
    local single = O.Create("Hero", { ChestSlot = NS.ItemInfo.Snapshot(info) })
    assertEqual(Bar.OutfitIcon(O.Get(single)), M.C_Item.GetItemIconByID(info.id))
    local two = O.Create("Two", { ChestSlot = NS.ItemInfo.Snapshot(info), HeadSlot = { id = 0 } })
    -- red under: the legacy plain icon (132662) or the coat hanger as the last rung.
    assertEqual(Bar.OutfitIcon(O.Get(two)), DEFAULT)
    local glyphed = accessory(NS, "Glyphed")
    O.SetIcon(glyphed, NS.Icon("ph:sword"), "ff0000")
    settle(M)
    local drawn = {}
    for _, btn in ipairs(Bar.Buttons()) do drawn[btn.outfit.id] = btn.icon:GetTexture() end
    assertEqual(drawn[own], 134401, "the button draws the ladder's answer")
    -- The button takes the resolver's tint, and a pooled button handed a fileID next is white again.
    local btn
    for _, b in ipairs(Bar.Buttons()) do if b.outfit.id == glyphed then btn = b end end
    assertEqual(btn.icon:GetTexture(), NS.Icon("ph:sword"))
    local r, g, b = btn.icon:GetVertexColor()
    assertTrue(r == 1 and g == 0 and b == 0, "the glyph's color")
    Bar.SetButton(btn, O.Get(own))
    r, g, b = btn.icon:GetVertexColor()
    -- red under: SetButton drawing the texture without resetting the tint.
    assertTrue(r == 1 and g == 1 and b == 1, "a fileID is drawn white")
end)

-- ── the icon border and the worn highlight ───────────────────────────────────────────────────

test("bar: an icon's border is the skin's HUD edge while it follows the skin, the player's when not", function()
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    settle(M)
    local btn = Bar.Buttons()[1]
    assertTrue(btn.skinEdge:IsShown(), "the skin's edge")
    assertTrue(btn.edge == nil or not btn.edge:IsShown(), "no edge of the player's")
    NS.SetByPath("bar.icons.borderColorFromSkin", false)
    NS.SetByPath("bar.icons.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    NS.SetByPath("bar.icons.borderStyleFromSkin", false)
    NS.SetByPath("bar.icons.borderSize", 2)
    settle(M)
    btn = Bar.Buttons()[1]
    -- red under: a button that keeps S.IconBorder's skin edge whatever the companions say
    assertFalse(btn.skinEdge:IsShown(), "the skin's edge steps aside")
    assertTrue(btn.edge ~= nil and btn.edge:IsShown(), "the player's edge")
    local r, g, b = btn.edge:GetBackdropBorderColor()
    assertTrue(r == 1 and g == 0 and b == 0, "the swatch")
    assertEqual(btn.edge:GetBackdrop().edgeSize, 2, "the thickness")
    NS.SetByPath("bar.icons.borderShow", false)
    settle(M)
    btn = Bar.Buttons()[1]
    assertFalse(btn.skinEdge:IsShown()); assertFalse(btn.edge:IsShown())
end)

test("bar: the worn highlight is the corner mark, an accent edge, both or neither", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    accessory(NS, "Hood")
    NS.Stack.Wear(hat, { hw = true })
    settle(M)
    local function shown()
        local btn = buttonFor(Bar, hat)
        local other = Bar.Buttons()[2]
        assertFalse(other.worn:IsShown() or (other.wornEdge ~= nil and other.wornEdge:IsShown()), "an outfit not worn")
        return btn.worn:IsShown(), btn.wornEdge ~= nil and btn.wornEdge:IsShown()
    end
    assertEqual(NS.GetSetting("bar.worn.style"), "both")
    local mark, edge = shown()
    -- red under: a worn style read as the mark alone
    assertTrue(mark and edge, "both by default")
    for style, want in pairs({ mark = { true, false }, border = { false, true }, none = { false, false } }) do
        NS.SetByPath("bar.worn.style", style)
        settle(M)
        mark, edge = shown()
        assertEqual(mark, want[1], style .. " mark")
        assertEqual(edge, want[2], style .. " edge")
    end
end)

-- ── clicks, drops, the menu, the tooltip ──────────────────────────────────────────────────────


test("bar: a left click wears; a worn accessory is removed; a worn Complete outfit stays on", function()
    local NS, M, Bar = scene()
    local normal, hat = complete(NS, "Normal"), accessory(NS, "Hat")
    settle(M)
    buttonFor(Bar, hat):__fire("OnClick", "LeftButton")
    settle(M)
    assertTrue(NS.Stack.IsWorn(hat))
    buttonFor(Bar, hat):__fire("OnClick", "LeftButton")
    settle(M)
    -- red under: a left click that always wears
    assertFalse(NS.Stack.IsWorn(hat), "the second click took it off")
    buttonFor(Bar, normal):__fire("OnClick", "LeftButton")
    settle(M)
    buttonFor(Bar, normal):__fire("OnClick", "LeftButton")
    settle(M)
    assertTrue(NS.Stack.IsWorn(normal), "a Complete outfit is re-worn, never removed")
end)

test("bar: a right click opens the outfit menu afresh on every open", function()
    local NS, M, Bar, ctl = scene()
    local hat = accessory(NS, "Hat")
    settle(M)
    local btn = buttonFor(Bar, hat)
    btn:__fire("OnClick", "RightButton")
    btn:__fire("OnClick", "RightButton")
    -- red under: a cached menu (quirk 21: the legacy kept the pooled frame and toggled it)
    assertEqual(ctl.menu.__count("Open"), 2)
    assertTrue(ctl.menu.__calls[1][2] == btn, "anchored on the button")
    assertEqual(ctl.menu.__calls[1][3], hat)
    assertFalse(NS.Stack.IsWorn(hat), "a right click wears nothing")
end)

test("bar: Alt + a dropped spell sets the icon through C_Spell; item and macro too", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    settle(M)
    local btn = buttonFor(Bar, hat)
    M.IsAltKeyDown = function() return true end
    M.GetSpellTexture = function() error("the removed GetSpellTexture was called") end
    M.C_Spell = { GetSpellTexture = function(id) return id == 12345 and 135000 or nil end }
    M.GetCursorInfo = function() return "spell", 7, "spell", 12345 end
    btn:__fire("OnReceiveDrag")
    -- red under: reading the spell's book index (GetCursorInfo's first value) instead of its id
    assertEqual(NS.Outfits.Get(hat).icon, 135000)
    M.GetMacroInfo = function(i) if i == 3 then return "m", 136000, "" end end
    M.GetCursorInfo = function() return "macro", 3 end
    btn:__fire("OnClick", "LeftButton")
    assertEqual(NS.Outfits.Get(hat).icon, 136000, "a click with a cursor is a drop")
    assertFalse(NS.Stack.IsWorn(hat), "the drop wore nothing")
    local info = NS.ItemInfo.FromBag(0, 5)
    M.GetCursorInfo = function() return "item", info.id, info.link end
    btn:__fire("OnReceiveDrag")
    assertEqual(NS.Outfits.Get(hat).icon, M.C_Item.GetItemIconByID(info.id))
end)

test("bar: Alt + a drop writes through the one icon writer, NS.Outfits.SetIcon", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    settle(M)
    local btn = buttonFor(Bar, hat)
    local seen = {}
    local real = NS.Outfits.SetIcon
    NS.Outfits.SetIcon = function(id, icon, color) seen[#seen + 1] = { id, icon, color }; return real(id, icon, color) end
    M.IsAltKeyDown = function() return true end
    M.GetMacroInfo = function(i) if i == 3 then return "m", 136000, "" end end
    M.GetCursorInfo = function() return "macro", 3 end
    btn:__fire("OnReceiveDrag")
    NS.Outfits.SetIcon = real
    -- red under: the drop writing the `outfit.icon` row itself (an EM outfit's set is never told).
    assertEqual(#seen, 1, "the drop did not go through NS.Outfits.SetIcon")
    assertEqual(seen[1][1], hat); assertEqual(seen[1][2], 136000)
    assertEqual(NS.Outfits.Get(hat).icon, 136000)
end)

test("bar: a dropped item without Alt becomes a new outfit named after it, worn", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    settle(M)
    local info = NS.ItemInfo.FromBag(0, 5)
    M.IsAltKeyDown = function() return false end
    M.GetCursorInfo = function() return "item", info.id, info.link end
    buttonFor(Bar, hat):__fire("OnReceiveDrag")
    settle(M)
    local made = NS.Outfits.FindByName(info.name)
    assertTrue(made ~= nil, "an outfit named after the item")
    assertTrue(NS.Stack.IsWorn(made), "and worn")
    -- red under: Bar.Drop routing a non-Alt item drop through dropIcon as well.
    assertNil(NS.Outfits.Get(hat).icon, "the target outfit is untouched")
end)

test("bar: a dropped item that cannot make an outfit stays on the cursor, and says why", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    settle(M)
    local function count()
        local n = 0
        for _, category in ipairs(NS.Outfits.Categories()) do
            for _ in NS.Outfits.Each(category) do n = n + 1 end
        end
        return n
    end
    local before = count()
    local cleared = 0
    M.ClearCursor = function() cleared = cleared + 1 end
    M.IsAltKeyDown = function() return false end
    M.GetCursorInfo = function() return "item", 6948, "|cffffffff|Hitem:6948::::::::::::|h[Hearthstone]|h|r" end
    buttonFor(Bar, hat):__fire("OnReceiveDrag")
    settle(M)
    assertEqual(count(), before, "no outfit made")
    -- red under: dropItem clearing the cursor before CreateFromItem answers (the item drops back silently).
    assertEqual(cleared, 0, "the item stays on the cursor")
    local said = 0
    for _, line in ipairs(M.__printed()) do
        if line:find("because it isn't equippable", 1, true) then said = said + 1 end
    end
    -- red under: dropItem returning on a nil CreateFromItem with nothing printed (OutfitterBar.lua:759-768).
    assertEqual(said, 1, "the reason is printed")
end)

test("bar: the hover shows the outfit tooltip with always = true, and hides GameTooltip when it shows nothing", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    settle(M)
    local tip = T.fake(NS, "OutfitTooltip", { Show = function() return false end })
    M.GameTooltip:Show()
    local btn = buttonFor(Bar, hat)
    btn:__fire("OnEnter")
    assertEqual(tip.__calls[1][2], hat)
    assertTrue(tip.__calls[1][3] == btn)
    -- red under: the window's call shape, without `always`
    assertEqual(tip.__calls[1][5], true)
    assertFalse(M.GameTooltip:IsShown(), "nothing shown, so GameTooltip is hidden")
end)

-- ── alpha, fades, combat ──────────────────────────────────────────────────────────────────────

test("bar: alpha 0 takes the mouse off every button; any other alpha gives it back", function()
    local NS, M, Bar = scene()
    complete(NS, "A"); accessory(NS, "B")
    settle(M)
    NS.SetByPath("alpha", 0)
    for _, btn in ipairs(Bar.Buttons()) do
        -- red under: an ApplyAlpha that never touches the mouse
        assertEqual(btn.__mouse, false)
    end
    NS.SetByPath("alpha", 0.5)
    for _, btn in ipairs(Bar.Buttons()) do assertEqual(btn.__mouse, true) end
    assertEqual(Bar.Frame():GetAlpha(), 0.5)
end)

test("bar: in combat the alpha is Master alpha times bar.combatAlpha, from PLAYER_STATE_CHANGED", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    NS.SetByPath("alpha", 0.8)
    NS.db.profile.bar.combatAlpha = 0.5
    settle(M)
    NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, "combat", true)
    -- red under: an EffectiveAlpha that ignores combat
    assertEqual(Bar.Frame():GetAlpha(), 0.4)
    NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, "combat", false)
    assertEqual(Bar.Frame():GetAlpha(), 0.8)
    NS.SetByPath("visibility", "outOfCombat")
    NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, "combat", true)
    settle(M)
    assertFalse(Bar.Frame():IsShown(), "the visibility rule hides it in combat")
end)

test("bar: leaving the bar fades it to its alpha over 0.5 s", function()
    local NS, M, Bar, ctl = scene()
    complete(NS, "A")
    NS.SetByPath("alpha", 0.6)
    settle(M)
    local f = Bar.Frame()
    f:__fire("OnEnter")
    assertEqual(f:GetAlpha(), 1, "full while hovered")
    f:__fire("OnLeave")
    local b
    for _, fade in ipairs(ctl.fades) do if fade[1] == f then b = fade end end
    -- red under: a fade of another length
    assertEqual(b[2], 0.5); assertEqual(b[3], 1); assertEqual(b[4], 0.6)
    assertEqual(#ctl.fades, 1, "one fade: there is no handle to fade")
    -- The header's close keeps the bar lit as its lock and drag strip do.
    f:SetAlpha(0.6)
    f.close:__fire("OnEnter")
    -- red under: the close X built without the bar's hover hooks (the bar fades under the pointer)
    assertEqual(f:GetAlpha(), 1, "full while the close is hovered")
    f.close:__fire("OnLeave")
    assertEqual(#ctl.fades, 2, "leaving the close fades the bar")
end)

test("bar: an alpha change stops a hover-out fade still running, so it cannot land on the old alpha", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    NS.SetByPath("alpha", 0.6)
    NS.db.profile.bar.combatAlpha = 0
    settle(M)
    local f = Bar.Frame()
    local stopped = {}
    M.UIFrameFadeRemoveFrame = function(frame) stopped[#stopped + 1] = frame end
    f:__fire("OnEnter"); f:__fire("OnLeave")             -- the 0.5 s fade to 0.6 starts
    stopped = {}
    NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, "combat", true)
    local hit = false
    for _, frame in ipairs(stopped) do hit = hit or frame == f end
    -- red under: ApplyAlpha without its fadeStop(bar) (the fade ends at 0.6 over combatAlpha 0).
    assertTrue(hit, "the running fade was not stopped")
    assertEqual(f:GetAlpha(), 0)
end)

-- ── the show decision and the lifecycle ───────────────────────────────────────────────────────

test("bar: hidden during a pet battle, back after it", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    assertTrue(Bar.Frame():IsShown())
    M.__fireEvent("PET_BATTLE_OPENING_START")
    -- red under: a show decision without inPetBattle
    assertFalse(Bar.Frame():IsShown())
    M.__fireEvent("PET_BATTLE_OVER")
    assertTrue(Bar.Frame():IsShown())
end)

test("bar: rebuilds are coalesced on one 0 s timer", function()
    local NS, M, Bar = scene()
    local n = 0
    local render = Bar.Render
    Bar.Render = function(...) n = n + 1; return render(...) end
    complete(NS, "A"); complete(NS, "B"); accessory(NS, "C")
    NS.SendBus(NS.MSG.SETTINGS_CHANGED, "bar.vertical", true)
    assertEqual(n, 0, "nothing drawn before the timer")
    settle(M)
    Bar.Render = render
    -- red under: a render per message
    assertEqual(n, 1)
end)

test("bar: a profile switch redraws the bar from the new profile and rebinds the triggers", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    local swim = NS.Outfits.Create("Swim", naked(), { trigger = "SWIMMING" })
    settle(M)
    -- The login's LoadPass: the binder binds, and from then on follows auto.enabled.
    NS.Outfits.LoadPass()
    settle(M)
    local B = NS.TriggerBinder
    assertTrue(B.IsBound(swim), "the fixture needs the trigger bound")
    -- "Alt": a larger bar in another corner, automatic changes off.
    NS.db:SetProfile("Alt")
    for _, e in ipairs({ { "bar.shown", true }, { "scale", 1.5 }, { "bar.position", "BOTTOMRIGHT -10 10" },
                         { "auto.enabled", false } }) do
        assertTrue(NS.SetByPath(e[1], e[2]), e[1])
    end
    NS.db:SetProfile("Default")
    settle(M)
    local f = Bar.Frame()
    assertEqual(f.__scale, 1); assertEqual(point(f)[1], "TOPLEFT")
    assertTrue(B.IsBound(swim), "back on Default, the trigger was not rebound")
    -- A switch writes no row, so no SETTINGS_CHANGED: only PROFILE_CHANGED can carry these.
    NS.db:SetProfile("Alt")
    settle(M)
    -- red under: PROFILE_CHANGED dropped from the bar's REBUILD list (modules/Bar.lua).
    assertEqual(f.__scale, 1.5, "the bar kept the old profile's scale")
    assertEqual(point(f)[1], "BOTTOMRIGHT", "the bar kept the old profile's corner")
    assertTrue(f:IsShown())
    -- red under: the binder's PROFILE_CHANGED registration (onProfile, modules/Triggers_Binder.lua) removed.
    assertFalse(B.IsBound(swim), "auto.enabled off in Alt, yet the trigger stayed bound")
    NS.db:SetProfile("Default")
    settle(M)
    assertEqual(f.__scale, 1)
    assertTrue(B.IsBound(swim), "the switch back did not bind the trigger again")
end)

test("bar: Suspend hides it and stops the rebuilds; the stand-down keeps it down", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    Bar.Suspend()
    assertFalse(Bar.Frame():IsShown())
    complete(NS, "B")
    settle(M)
    assertFalse(Bar.Frame():IsShown(), "a message heard while suspended shows nothing")
    assertFalse(Bar.Refresh(), "suspended: never shown")
    Bar.Resume()
    settle(M)
    assertTrue(Bar.Frame():IsShown())
    NS.SetByPath("enabled", false)
    assertTrue(NS.IsStoodDown())
    assertFalse(Bar.Frame():IsShown(), "the stand-down hid it")
    -- A stray Resume while the latch is held still shows nothing.
    Bar.Resume()
    settle(M)
    -- red under: a show decision that skips the latch
    assertFalse(Bar.Refresh())
    assertFalse(Bar.Frame():IsShown())
end)

test("bar: test mode shows the sample outfits with the strip, even with the bar off, and they do nothing", function()
    local NS, M, Bar, ctl = scene({ hidden = true })
    complete(NS, "Real")
    ctl.preview = true
    ctl.previewRows = { { categoryID = "Complete", outfits = {
        { id = "preview:1", name = "Test Outfit 1", icon = 132276, placeholder = true },
        { id = "preview:2", name = "Test Outfit 2", icon = 1376041, placeholder = true } } } }
    NS.SendBus(NS.MSG.PREVIEW_CHANGED, true)
    settle(M)
    local f = Bar.Frame()
    assertTrue(f:IsShown(), "test mode shows the bar")
    assertEqual(ids(Bar), "preview:1,preview:2")
    assertTrue(f.strip ~= nil and f.strip:IsShown(), "the strip is up")
    local sp = point(f.strip)
    -- red under: the strip anchored at the container's top, over the header band
    assertTrue(sp[2] == Bar.Band() and sp[3] == "BOTTOMLEFT", "the strip hangs under the band")
    local first = point(Bar.Buttons()[1]:GetParent())
    assertEqual(first[5], -(Bar.HeaderHeight(true) + NS.GetSetting("bar.layout.padding")), "the rows sit below the strip")
    assertTrue(Bar.HeaderHeight(true) >= Bar.HeaderHeight() + NS.TEST_STRIP_HEIGHT, "the strip adds its height")
    local btn = Bar.Buttons()[1]
    assertFalse(btn.worn:IsShown())
    assertEqual(btn.icon:GetTexture(), 132276)
    btn:__fire("OnClick", "LeftButton")
    btn:__fire("OnClick", "RightButton")
    M.IsAltKeyDown = function() return true end
    M.GetCursorInfo = function() return "macro", 1 end
    btn:__fire("OnReceiveDrag")
    settle(M)
    -- red under: a click path that skips the placeholder check
    assertEqual(ctl.menu.__count("Open"), 0)
    assertEqual(#NS.db.char.stack, 0, "nothing worn")
    btn:__fire("OnEnter")
    assertEqual(M.GameTooltip.TextLeft2:GetText(), "Sample outfit (test mode). Nothing is equipped.")
    ctl.preview = false
    NS.SendBus(NS.MSG.PREVIEW_CHANGED, false)
    settle(M)
    assertFalse(f:IsShown(), "back to the live bar, which is off")
    assertFalse(f.strip:IsShown())
end)
