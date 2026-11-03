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
                         "ResetPosition", "OutfitIcon", "Suspend", "Resume", "Buttons", "Frame",
                         "NewButton", "SetButton", "Drop", "ShouldShow" }) do
        assertEqual(type(Bar[k]), "function", k)
    end
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

test("bar: the buttons grow away from the saved corner, per quadrant, both orientations", function()
    local NS, _, Bar = scene()
    complete(NS, "A"); complete(NS, "B"); accessory(NS, "C")
    local want = { TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 } }
    for corner, sign in pairs(want) do
        for _, vertical in ipairs({ false, true }) do
            NS.db.profile.windows.bar = { point = corner, x = 0, y = 0 }
            NS.db.profile.bar.vertical = vertical
            Bar.Refresh()
            local btns = Bar.Buttons()
            local second = point(btns[2])
            assertEqual(second[1], corner, corner .. " anchors at its corner")
            -- red under: a QUADRANT row with a flipped sign
            if vertical then
                assertEqual(second[4], 0, corner .. " vertical x")
                assertEqual(second[5], sign[2] * Bar.PITCH, corner .. " vertical y")
            else
                assertEqual(second[4], sign[1] * Bar.PITCH, corner .. " horizontal x")
                assertEqual(second[5], 0, corner .. " horizontal y")
            end
            local row2 = point(btns[3]:GetParent())
            if vertical then
                assertEqual(row2[4], sign[1] * Bar.PITCH, corner .. " second column")
            else
                assertEqual(row2[5], sign[2] * Bar.PITCH, corner .. " second row")
            end
            local bar = point(Bar.Frame())
            assertEqual(bar[1], corner); assertEqual(bar[3], corner)
        end
    end
end)

test("bar: the size, the scale and the backplate follow the settings", function()
    local NS, M, Bar = scene()
    complete(NS, "A"); complete(NS, "B"); complete(NS, "C"); accessory(NS, "D")
    settle(M)
    local f = Bar.Frame()
    assertEqual(f.__w, 3 * Bar.PITCH); assertEqual(f.__h, 2 * Bar.PITCH)
    NS.SetByPath("scale", 1.5)
    settle(M)
    assertEqual(f.__scale, 1.5)
    local p = point(f)
    assertEqual(p[4], 200 / 1.5, "the offset is divided by the effective scale")
    NS.db.profile.bar.showBackground = false
    NS.SendBus(NS.MSG.SETTINGS_CHANGED, "bar.showBackground", false)
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

test("bar: the reset copies the default, so a drag after it never writes the default", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    settle(M)
    NS.db.profile.windows.bar = { point = "BOTTOMRIGHT", x = -5, y = 5 }
    Bar.ResetPosition()
    local p, d = NS.db.profile.windows.bar, NS.defaults.profile.windows.bar
    assertEqual(p.point, d.point); assertEqual(p.x, d.x); assertEqual(p.y, d.y)
    -- red under: `NS.db.profile.windows.bar = d` (the legacy alias, OutfitterBar.lua:107-115)
    assertFalse(p == d, "a copy, not the default itself")
    p.x = 999
    assertEqual(d.x, 200, "the default is untouched")
end)

-- ── the icon ladder ───────────────────────────────────────────────────────────────────────────

test("bar: the icon ladder: own, the trigger's descriptor, the Birthday Suit, a single item, plain", function()
    local NS, M, Bar = scene()
    local O = NS.Outfits
    local own = accessory(NS, "Own")
    NS.SetByPath("outfit.icon", 134400 + 1, own)
    assertEqual(Bar.OutfitIcon(O.Get(own)), 134401)
    local solo = accessory(NS, "Solo")
    -- red under: a name-keyed ladder (the legacy `Solo` key): the name alone draws the plain icon
    assertEqual(Bar.OutfitIcon(O.Get(solo)), Bar.PLAIN_ICON)
    NS.SetByPath("outfit.trigger.id", "INSTANCE_DIFFICULTY", solo)
    assertEqual(Bar.OutfitIcon(O.Get(solo)), 132132, "INSTANCE_DIFFICULTY's icon replaces Solo")
    local dungeon = accessory(NS, "Dungeon")
    NS.SetByPath("outfit.trigger.id", "IN_DUNGEON", dungeon)
    assertEqual(Bar.OutfitIcon(O.Get(dungeon)), Bar.PLAIN_ICON, "a descriptor with no icon falls through")
    local nakedRec = O.Get(complete(NS, "Birthday"))
    nakedRec.builtin = "NAKED"
    assertEqual(Bar.OutfitIcon(nakedRec), Bar.NAKED_ICON)
    local info = NS.ItemInfo.FromBag(0, 5)
    local single = O.Create("Hero", { ChestSlot = NS.ItemInfo.Snapshot(info) })
    assertEqual(Bar.OutfitIcon(O.Get(single)), M.C_Item.GetItemIconByID(info.id))
    local two = O.Create("Two", { ChestSlot = NS.ItemInfo.Snapshot(info), HeadSlot = { id = 0 } })
    assertEqual(Bar.OutfitIcon(O.Get(two)), Bar.PLAIN_ICON)
    settle(M)
    local drawn = {}
    for _, btn in ipairs(Bar.Buttons()) do drawn[btn.outfit.id] = btn.icon:GetTexture() end
    assertEqual(drawn[own], 134401, "the button draws the ladder's answer")
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
    assertEqual(first[5], -(NS.TEST_STRIP_HEIGHT + 2), "the rows sit below the strip")
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
