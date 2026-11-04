-- tests/test_bar.lua — P4.20 (design §7.7, INV §7.6): modules/Bar.lua's container, layout, show
-- decision, alpha, fades, position and lifecycle, and modules/Bar_Buttons.lua's icon ladder, clicks,
-- drops and tooltip.
--
-- NS.Preview and NS.Dock run against recorded fakes (design §12, the fake rule), so a case sets test
-- mode and the window's state itself; NS.OutfitMenu is the real menu under a recorder (tests/spy.lua,
-- its fake retired at P4.27). Outfits, Stack, Equip, Inventory, Triggers and OutfitTooltip are
-- the real modules, and the items move for real in tests/mock_gear.lua. The bar's frames are built
-- lazily, so the kit's paint and layer recorders and this file's geometry recorder are installed after
-- the load and still see every frame the bar makes.

local T = _G.OUTFITTERREBORN_TEST
local spy = dofile(T.root .. "/tests/spy.lua")
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "MainHandSlot", "SecondaryHandSlot", "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot",
    "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
}

--- Every frame built from here on records its points, mouse, scale and size, and answers geometry
--- from `geom` when the suite sets it.
local function recordGeometry(M)
    local prev = M.CreateFrame
    M.CreateFrame = function(...)
        local f = prev(...)
        if type(f) ~= "table" then return f end
        rawset(f, "__pts", {})
        rawset(f, "SetPoint", function(self, ...) local p = rawget(self, "__pts"); p[#p + 1] = { ... } end)
        rawset(f, "ClearAllPoints", function(self) rawset(self, "__pts", {}) end)
        rawset(f, "EnableMouse", function(self, on) rawset(self, "__mouse", on and true or false) end)
        rawset(f, "SetScale", function(self, s) rawset(self, "__scale", s) end)
        rawset(f, "GetScale", function(self) return rawget(self, "__scale") or 1 end)
        rawset(f, "GetEffectiveScale", function(self) return rawget(self, "__scale") or 1 end)
        rawset(f, "SetSize", function(self, w, h) rawset(self, "__w", w); rawset(self, "__h", h) end)
        return f
    end
end

--- Arm `f`'s edges (UIParent was built before the recorder, so they are set on the frame itself).
local function geom(f, left, right, top, bottom)
    local g = { Left = left, Right = right, Top = top, Bottom = bottom }
    for edge, v in pairs(g) do rawset(f, "Get" .. edge, function() return v end) end
end

local function naked()
    local items = {}
    for _, s in ipairs(SLOTS) do items[s] = { id = 0 } end
    return items
end

--- A fresh instance at t = 100 on the geared scenario, the engine resumed, the recorders in, the
--- two fakes and the menu recorder installed, and the bar resumed with `bar.shown` on unless `opts.hidden`.
local function scene(opts)
    opts = opts or {}
    local inst = T.load({ mutate = function(M) M.__gear:load("geared") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    M.__fireTimers()
    dofile(T.root .. "/tests/_kit/mock_paint.lua")(M)
    dofile(T.root .. "/tests/_kit/mock_layers.lua")(M)
    recordGeometry(M)
    local ctl = { preview = false, previewRows = {}, fades = {}, stops = 0 }
    M.UIFrameFadeOut = function(f, secs, from, to) ctl.fades[#ctl.fades + 1] = { f, secs, from, to } end
    M.UIFrameFadeRemoveFrame = function() ctl.stops = ctl.stops + 1 end
    -- Both are in the latch's MODULES walk, so each answers Suspend and Resume too.
    T.fake(NS, "Dock", { IsShown = function() return false end, Suspend = true, Resume = true })
    local preview = T.fake(NS, "Preview", { IsActive = function() return ctl.preview end, Suspend = true,
                                            Resume = true })
    rawset(preview, "Source", { Rows = function() return ctl.previewRows end })
    ctl.menu = spy(NS, "OutfitMenu", { "Open" })
    if not opts.hidden then NS.db.profile.bar.shown = true end
    NS.Bar.Resume()
    M.__fireTimers()
    return NS, M, NS.Bar, ctl
end

local function complete(NS, name) return NS.Outfits.Create(name, naked()) end
local function accessory(NS, name, slot) return NS.Outfits.Create(name, { [slot or "HeadSlot"] = { id = 0 } }) end

local function ids(Bar)
    local out = {}
    for _, btn in ipairs(Bar.Buttons()) do out[#out + 1] = btn.outfit.id end
    return table.concat(out, ",")
end

local function settle(M) M.__fireTimers() end

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

local function point(f, i) return f.__pts[i or 1] end

--- A button's TOPLEFT offset in the bar, as Render anchored it: x, y with y down.
local function at(btn)
    local p = point(btn)
    return p[4], -p[5]
end

test("bar: the layout's defaults keep the legacy 37 px pitch, 4 px in from the edge", function()
    local Layout = T.NS.Bar.Layout
    local D = T.NS.defaults.profile.bar
    -- red under: a spacing default other than 5 (the legacy Style.ButtonBar pitch, OutfitterUITools.lua)
    assertEqual(D.icons.size + D.layout.spacing, 37)
    assertEqual(D.layout.padding, 4)
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
    local top = Bar.HeaderHeight()
    local x1, y1 = at(btns[1])
    assertEqual(x1, 6); assertEqual(y1, top + 6)
    local x2 = at(btns[2])
    -- red under: Render keeping the fixed 37 px PITCH
    assertEqual(x2 - x1, 23)
    assertEqual(btns[1].__w, 20, "the icon size")
    local _, y4 = at(btns[4])
    assertEqual(y4 - y1, 23, "the second category's row")
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

test("bar: the backplate follows bar.showBackground", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    assertTrue(f.bg:IsShown())
    NS.SetByPath("bar.showBackground", false)
    settle(M)
    -- red under: Render's bg:SetShown ignoring bar.showBackground (always true).
    assertFalse(f.bg:IsShown())
end)

-- ── position ──────────────────────────────────────────────────────────────────────────────────

test("bar: the drag stop saves the nearest corner; a locked bar does not move", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    geom(M.UIParent, 0, 1000, 800, 0)
    geom(f, 900, 950, 100, 50)
    local handle = f.handle
    assertTrue(handle ~= nil, "a drag handle was built")
    assertTrue(handle:IsShown(), "shown while unlocked")
    handle:__fire("OnDragStart")
    handle:__fire("OnDragStop")
    local p = NS.db.profile.windows.bar
    assertEqual(p.point, "BOTTOMRIGHT"); assertEqual(p.x, -50); assertEqual(p.y, 50)
    geom(f, 10, 60, 790, 740)
    assertEqual(Bar.SavePosition().point, "TOPLEFT")
    assertEqual(NS.db.profile.windows.bar.y, -10)
    NS.SetByPath("locked", true)
    settle(M)
    assertFalse(handle:IsShown(), "hidden while locked")
    geom(f, 900, 950, 100, 50)
    handle:__fire("OnDragStart")
    handle:__fire("OnDragStop")
    -- red under: a canDrag that ignores the lock
    assertEqual(NS.db.profile.windows.bar.point, "TOPLEFT", "a locked bar saved nothing")
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
    f.handle:__fire("OnDragStart")
    f.handle:__fire("OnDragStop")
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

-- ── clicks, drops, the menu, the tooltip ──────────────────────────────────────────────────────

local function buttonFor(Bar, id)
    for _, btn in ipairs(Bar.Buttons()) do
        if btn.outfit.id == id then return btn end
    end
end

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

test("bar: leaving the bar fades the handle over 0.3 s and the bar to its alpha over 0.5 s", function()
    local NS, M, Bar, ctl = scene()
    complete(NS, "A")
    NS.SetByPath("alpha", 0.6)
    settle(M)
    local f = Bar.Frame()
    f:__fire("OnEnter")
    assertEqual(f:GetAlpha(), 1, "full while hovered")
    f:__fire("OnLeave")
    local byFrame = {}
    for _, fade in ipairs(ctl.fades) do byFrame[fade[1]] = fade end
    local h, b = byFrame[f.handle], byFrame[f]
    -- red under: swapped durations
    assertEqual(h[2], 0.3); assertEqual(h[3], 1); assertEqual(h[4], 0)
    assertEqual(b[2], 0.5); assertEqual(b[3], 1); assertEqual(b[4], 0.6)
    ctl.fades = {}
    NS.SetByPath("locked", true)
    settle(M)
    f:__fire("OnEnter"); f:__fire("OnLeave")
    for _, fade in ipairs(ctl.fades) do assertFalse(fade[1] == f.handle, "no handle fade while locked") end
end)

test("bar: a rebuild leaves a faded handle faded; an unlock shows it again", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    assertEqual(f.handle:GetAlpha(), 1, "unlocked: the handle shows")
    f:__fire("OnEnter"); f:__fire("OnLeave")
    f.handle:SetAlpha(0)                                 -- where UIFrameFadeOut leaves it
    NS.SendBus(NS.MSG.OUTFIT_EDITED, NS.Outfits.FindByName("A"), "name")
    settle(M)
    assertTrue(f.handle:IsShown())
    -- red under: SetLocked's SetAlpha(1) on every refresh (any rebuild brought the handle back).
    assertEqual(f.handle:GetAlpha(), 0, "the rebuild left the faded handle alone")
    NS.SetByPath("locked", true); settle(M)
    NS.SetByPath("locked", false); settle(M)
    assertEqual(f.handle:GetAlpha(), 1, "an unlock shows it at full alpha")
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

test("bar: the clamp covers the handle above the bar while it shows, and only then", function()
    local NS, M, Bar = scene()
    local insets
    complete(NS, "A")
    settle(M)
    local f = Bar.Frame()
    rawset(f, "SetClampRectInsets", function(_, l, r, t, b) insets = { l, r, t, b } end)
    NS.SendBus(NS.MSG.SETTINGS_CHANGED, "bar.vertical", false)
    settle(M)
    -- red under: no SetClampRectInsets (a drag to the top edge pushes the handle off screen).
    assertTrue(insets ~= nil and insets[3] >= 18 + 2, "the top inset reaches over the handle")
    assertEqual(insets[1], 0); assertEqual(insets[2], 0); assertEqual(insets[4], 0)
    NS.SetByPath("locked", true); settle(M)
    assertEqual(insets[3], 0, "locked: no handle, no inset")
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
