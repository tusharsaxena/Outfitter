-- tests/test_preview_place.lua — where test mode puts its two surfaces (smoke round 3 E3): the
-- window stands alone in the SCREEN CENTRE and drags for the length of the test session (out of
-- combat only, never saved: the client's user-placed flag is cleared after the drop), and the bar
-- starts just left of that spot for the session, stays draggable, and a drag of it saves as it always
-- does. Docked beside the sheet the window does not move. test_preview pins the rest of test mode.
--
-- The surfaces run for real (tests/dock_scene.lua, the bar resumed on top), with UIParent laid out
-- 1920 x 1080 so the center has a screen to hang from.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local dockScene = dofile(T.root .. "/tests/dock_scene.lua")(T)

local SCREEN_W, SCREEN_H = 1920, 1080
-- The gap between the bar's right edge and the window's left (modules/Bar.lua TEST_GAP).
local GAP = 8

local function scene(opts)
    local NS, M, fakes = dockScene(opts)
    M.__sheets.place(M.UIParent, SCREEN_W, SCREEN_H)
    NS.Bar.Resume()
    M.__fireTimers()
    return NS, M, fakes
end

local function win(M) return M.OutfitterRebornWindow end
local function lastPoint(f) return f.__pts[#f.__pts] end

--- The alone window's centered TOPLEFT, in UIParent's units: 260 wide, 320 high plus the test strip.
local function center(NS)
    local h = 320 + NS.TEST_STRIP_HEIGHT + 2
    return (SCREEN_W - 260) / 2, (SCREEN_H + h) / 2
end

local function pointIs(M, p, x, top)
    return p[1] == "TOPLEFT" and p[2] == M.UIParent and p[3] == "BOTTOMLEFT" and p[4] == x and p[5] == top
end

--- Lay `f`'s rect out at left/top (what the client answers once the player dropped it there).
local function dropAt(f, left, top)
    rawset(f, "GetLeft", function() return left end)
    rawset(f, "GetTop", function() return top end)
end

local function dump(v)
    if type(v) ~= "table" then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function saved(NS) return dump({ profile = NS.db.profile, char = NS.db.char, global = NS.db.global }) end

-- ── the window ────────────────────────────────────────────────────────────────────────────────

test("test place: with the sheet closed, the test window opens alone in the screen center", function()
    local NS, M = scene()
    NS.Preview.Start()
    local w = win(M)
    assertTrue(w:IsShown(), "test mode did not show the window")
    local x, top = center(NS)
    -- red under: the alone spot at the stock sheet's right (round 2's AloneCorner, 556 / 964)
    assertTrue(pointIs(M, lastPoint(w), x, top), "the alone window is not centered")
end)

test("test place: alone, the window drags; the drop holds for the session and nothing is saved", function()
    local NS, M = scene()
    local before = saved(NS)
    NS.Preview.Start()
    local w = win(M)
    w:__fire("OnDragStart", "LeftButton")
    -- red under: no OnDragStart on the window (round 2: "still not movable")
    assertTrue(w:IsUserPlaced(), "the drag did not start the move")
    dropAt(w, 100, 700)
    w:__fire("OnDragStop")
    assertEqual(w.__stopCount, 1, "the drop did not stop the move")
    -- red under: a drop that leaves the client's flag set (layout-local.txt would keep the spot)
    assertFalse(w:IsUserPlaced(), "the dropped window is still flagged user-placed")
    assertTrue(pointIs(M, lastPoint(w), 100, 700), "the drop was not re-issued as the dock's one point")
    -- The follow and every Refresh keep the dropped spot for the session.
    local n = #w.__pts
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 1)
    assertEqual(#w.__pts, n, "the follow pulled the dropped window back")
    NS.Dock.Refresh()
    -- red under: an alone corner that forgets the session's drop
    assertTrue(pointIs(M, lastPoint(w), 100, 700), "a Refresh moved the dropped window")
    -- The sheet docks it; its close puts it back where the player dropped it.
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    assertTrue(pointIs(M, lastPoint(w), 300, 500), "the open sheet did not dock it")
    M.__world:closeCharacter()
    assertTrue(pointIs(M, lastPoint(w), 100, 700), "the closed sheet did not put it back at the drop")
    -- A new session starts in the center again, and nothing was ever written.
    NS.Preview.Stop()
    NS.Preview.Start()
    local x, top = center(NS)
    -- red under: a session spot that outlives its session
    assertTrue(pointIs(M, lastPoint(w), x, top), "the next session did not start centered")
    NS.Preview.Stop()
    assertEqual(saved(NS), before, "the drag wrote saved data")
end)

test("test place: docked beside the sheet, or in lockdown, the window does not move", function()
    local NS, M = scene()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    local w = win(M)
    w:__fire("OnDragStart", "LeftButton")
    -- red under: an OnDragStart that does not ask whether the window stands alone
    assertFalse(w:IsUserPlaced(), "the docked window started moving")
    NS.Preview.Start()
    w:__fire("OnDragStart", "LeftButton")
    assertFalse(w:IsUserPlaced(), "the docked test window started moving")
    M.__world:closeCharacter()
    assertTrue(w:IsShown(), "the test window did not stand alone")
    M.__lockdown = true
    w:__fire("OnDragStart", "LeftButton")
    -- red under: an OnDragStart that does not read the lockdown (the window holds secure buttons)
    assertFalse(w:IsUserPlaced(), "the window started moving in lockdown")
    M.__lockdown = false
end)

test("test place: combat mid-drag stops the move before lockdown and ends test mode", function()
    local NS, M = scene()
    NS.Preview.Start()
    local w = win(M)
    w:__fire("OnDragStart", "LeftButton")
    dropAt(w, 200, 600)
    M.__fire("PLAYER_REGEN_DISABLED")
    -- red under: a hide that leaves the move running into combat
    assertEqual(w.__stopCount, 1, "the move was not stopped when combat came")
    assertFalse(w:IsUserPlaced(), "the stopped move left the window user-placed")
    assertFalse(w:IsShown())
    M.__fireTimers()
    assertFalse(NS.Preview.IsActive())
end)

-- ── the bar ───────────────────────────────────────────────────────────────────────────────────

--- The bar's TOPRIGHT just left of the centered window, in screen pixels from UIParent's TOPRIGHT.
local function barBeside(NS)
    local x, top = center(NS)
    return x - GAP - SCREEN_W, top - SCREEN_H
end

test("test place: the bar starts just left of the window, and the saved place is left alone", function()
    local NS, M = scene()
    local before = dump(NS.db.profile.windows.bar)
    NS.Preview.Start()
    M.__fireTimers()
    local bar = NS.Bar.Frame()
    assertTrue(bar:IsShown(), "test mode did not show the bar")
    local p, x, y = lastPoint(bar), barBeside(NS)
    -- red under: a test-mode bar anchored at its saved corner (19.png: stacked on the window)
    assertEqual(p[1], "TOPRIGHT"); assertTrue(p[2] == M.UIParent); assertEqual(p[3], "TOPRIGHT")
    assertEqual(p[4], x); assertEqual(p[5], y)
    -- An explicit grow direction that disagrees with the saved corner (TOPLEFT) does not re-save the
    -- session's place as the player's.
    NS.SetByPath("bar.layout.growH", "left")
    M.__fireTimers()
    -- red under: Refresh's CornerDisagrees re-save, or the grow write's re-save, while the bar
    -- stands at its test place
    assertEqual(dump(NS.db.profile.windows.bar), before, "test mode wrote the bar's place")
    p = lastPoint(bar)
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[4], x)
end)

test("test place: a drag of the test bar saves as usual, and test mode's end keeps it there", function()
    local NS, M = scene()
    NS.db.profile.bar.shown = true
    NS.Preview.Start()
    M.__fireTimers()
    local bar = NS.Bar.Frame()
    local function geom(f, left, right, top, bottom)
        for edge, v in pairs({ Left = left, Right = right, Top = top, Bottom = bottom }) do
            rawset(f, "Get" .. edge, function() return v end)
        end
    end
    geom(M.UIParent, 0, SCREEN_W, SCREEN_H, 0)
    geom(bar, 10, 60, 1070, 1020)
    bar.drag:__fire("OnDragStart")
    bar.drag:__fire("OnDragStop")
    local p = NS.db.profile.windows.bar
    -- red under: a drag that only moves the session's place
    assertEqual(p.point, "TOPLEFT"); assertEqual(p.x, 10); assertEqual(p.y, -10)
    M.__fireTimers()
    local pt = lastPoint(bar)
    -- red under: a redraw that puts the bar back at the session's place after the drag
    assertEqual(pt[1], "TOPLEFT"); assertEqual(pt[4], 10); assertEqual(pt[5], -10)
    NS.Preview.Stop()
    M.__fireTimers()
    assertTrue(bar:IsShown(), "the player's bar went with test mode")
    pt = lastPoint(bar)
    assertEqual(pt[1], "TOPLEFT"); assertEqual(pt[4], 10)
    -- The next session starts beside the window again.
    NS.Preview.Start()
    M.__fireTimers()
    pt = lastPoint(bar)
    -- red under: a session place (or a drag's end of it) that outlives its session
    assertEqual(pt[1], "TOPRIGHT", "the next session's bar is not beside the window")
    assertEqual(pt[4], (barBeside(NS)))
end)

test("test place: test mode's end puts a bar the player had on back at its saved place", function()
    local NS, M = scene()
    NS.db.profile.bar.shown = true
    NS.db.profile.windows.bar = { point = "BOTTOMLEFT", x = 40, y = 30 }
    M.__fireTimers()
    NS.Preview.Start()
    M.__fireTimers()
    local bar = NS.Bar.Frame()
    assertEqual(lastPoint(bar)[1], "TOPRIGHT", "the test bar is not beside the window")
    NS.Preview.Stop()
    M.__fireTimers()
    local pt = lastPoint(bar)
    -- red under: a session place that outlives test mode
    assertEqual(pt[1], "BOTTOMLEFT"); assertEqual(pt[4], 40); assertEqual(pt[5], 30)
end)
