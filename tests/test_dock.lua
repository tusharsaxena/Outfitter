-- tests/test_dock.lua — P4.19 (design §7.0-§7.2, H4, INV §7.1, §16.1-§16.2): modules/Dock.lua, the
-- window's show model, follow and layer sync, and the sheet button.
--
-- The window is docked, never anchored: one UIParent-relative SetPoint, re-issued from a 0.05 s
-- follow on an owned driver frame. Its strata and level are the sheet holder's (level + DOCK_OVER_HOST),
-- written through NS.SecureQueue because it holds secure children. It is never shown during combat
-- lockdown: PLAYER_REGEN_DISABLED hides it, PLAYER_REGEN_ENABLED brings it back.

local T = _G.OUTFITTERREBORN_TEST
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local RETAIL_ONLY = "Retail's sheet button (sidebar tab, EllesmereUI, Chonky); WoW Forever's is the outer side-tab strip (ruling D8)"
local FOREVER_ONLY = "pins WoW Forever's sheet button (ruling D8); runs on the forever kit profile"
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dock_scene.lua")(T)

local DOCK_OVER_HOST = 1

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end
-- The fake sheet re-strataed by the host: a host value, never one of ours (C.LAYERS).
local RAISED_HOST_STRATA = "HIGH"

-- The scene with the sheet (CharacterFrame, the stock sheet's NS.Sheet.Frame()) laid out at
-- (right 300, top 500) and the window open on it.
local function opened()
    local NS, M, fakes = scene()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    return NS, M, fakes, M.OutfitterRebornWindow
end

-- Count calls of `method` on `frame` (wrapped, so the original still runs).
local function spy(frame, method)
    local n, orig = { count = 0, args = {} }, frame[method]
    rawset(frame, method, function(self, ...)
        n.count = n.count + 1
        n.args[#n.args + 1] = { ... }
        return orig(self, ...)
    end)
    return n
end

local function printed(M, needle)
    local n = 0
    for _, line in ipairs(M.__printed()) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

test("dock: NS.Dock is published with the §7.2 surface", function()
    local D = T.NS.Dock
    assertEqual(type(D), "table")
    for _, k in ipairs({ "Open", "Close", "Toggle", "IsShown", "Refresh", "ShouldShow", "ApplyLayers",
                         "Attach", "Holder", "Install", "Suspend", "Resume" }) do
        assertEqual(type(D[k]), "function", k)
    end
    assertEqual(D.Y_OFFSET, 0); assertEqual(D.FOLLOW_INTERVAL, 0.05)
end)

test("dock: the holder fills the sheet, and the sheet button toggles the window", function()
    local NS, M = scene()
    local holder, button = M.OutfitterRebornSheetHolder, M.OutfitterRebornSheetButton
    assertEqual(holder:GetParent(), M.PaperDollFrame)
    assertEqual(NS.Dock.Holder(), holder)
    M.__world:openCharacter()
    assertFalse(NS.Dock.IsShown(), "the window opens only when asked")
    button:__fire("OnClick", "LeftButton")
    assertTrue(NS.Dock.IsShown())
    button:__fire("OnClick", "LeftButton")
    assertFalse(NS.Dock.IsShown())
end)

test("dock: strata and level are copied from the host, level + DOCK_OVER_HOST, never toplevel", function()
    local NS, M, _, win = opened()
    local holder = M.OutfitterRebornSheetHolder
    assertEqual(win:GetFrameStrata(), holder:GetFrameStrata())
    assertEqual(win:GetFrameLevel(), holder:GetFrameLevel() + DOCK_OVER_HOST)
    assertFalse(win:IsToplevel(), "the window is not toplevel")
    assertEqual(win:GetParent(), M.UIParent, "the window is detached from the sheet")
    -- The sheet raised and re-strataed: the next follow tick re-syncs.
    M.CharacterFrame:SetFrameStrata(RAISED_HOST_STRATA)
    M.CharacterFrame:SetFrameLevel(20)
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    -- red under: copy a fixed strata (L.STRATA.HUD) in Dock.ApplyLayers instead of the host's.
    assertEqual(win:GetFrameStrata(), RAISED_HOST_STRATA)
    assertEqual(win:GetFrameLevel(), holder:GetFrameLevel() + DOCK_OVER_HOST)
    -- The rows and the scroll bar sit above the window's own level.
    assertTrue(NS.WindowRows.rows[1]:GetFrameLevel() > win:GetFrameLevel())
    assertTrue(M.OutfitterRebornWindowScroll:GetFrameLevel() > NS.WindowRows.rows[1]:GetFrameLevel())
end)

test("dock: a secret host strata is never copied onto the window (OR-F4)", function()
    local NS, M, _, win = opened()
    local holder = M.OutfitterRebornSheetHolder
    local before, get = win:GetFrameStrata(), holder.GetFrameStrata
    rawset(holder, "GetFrameStrata", function() return T.secret(RAISED_HOST_STRATA) end)
    NS.Dock.lastStrata = nil
    NS.Dock.ApplyLayers()
    holder.GetFrameStrata = get
    -- red under: Dock.ApplyLayers copying holder:GetFrameStrata() without the secret guard.
    assertEqual(win:GetFrameStrata(), before)
end)

test("dock: the layer writes go through NS.SecureQueue in lockdown and replay on REGEN_ENABLED", function()
    local NS, M, _, win = opened()
    local holder = M.OutfitterRebornSheetHolder
    local before = win:GetFrameLevel()
    M.__lockdown = true
    M.CharacterFrame:SetFrameLevel(30)
    NS.Dock.ApplyLayers()
    -- red under: write the strata and level straight from Dock.ApplyLayers (no NS.SecureQueue.Run).
    assertEqual(win:GetFrameLevel(), before, "a layer write ran in lockdown")
    M.__world:setCombat(false)
    assertEqual(win:GetFrameLevel(), holder:GetFrameLevel() + DOCK_OVER_HOST, "the queued write never replayed")
end)

test("dock: Refresh never shows or hides the window in lockdown", function()
    local NS, M, _, win = opened()
    local shows, hides = spy(win, "Show"), spy(win, "Hide")
    M.__lockdown = true
    NS.Dock.wanted = false
    NS.Dock.Refresh()
    NS.Dock.Close()
    -- red under: drop the `if locked() then return end` at the top of Dock.Refresh.
    assertEqual(hides.count, 0, "Refresh hid the window in lockdown")
    M.__lockdown = false
    NS.Dock.Close()
    assertEqual(hides.count, 1)
    M.__lockdown = true
    M.__resetPrinted()
    NS.Dock.Open()
    NS.Dock.Open()
    assertEqual(shows.count, 0, "Refresh showed the window in lockdown")
    assertTrue(NS.Dock.wanted, "an Open in lockdown keeps the wish")
    -- red under: print the combat line on every Open (no `toldCombat` latch).
    assertEqual(printed(M, "The Outfitter window opens when combat ends."), 1)
    M.__lockdown = false
    M.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(NS.Dock.IsShown(), "the window did not open when combat ended")
end)

test("dock: PLAYER_REGEN_DISABLED hides the window, PLAYER_REGEN_ENABLED restores it, dialogs stay", function()
    local NS, M, fakes, win = opened()
    assertTrue(win:IsShown())
    M.__fire("PLAYER_REGEN_DISABLED")
    M.__lockdown = true
    -- red under: drop the REGEN_DISABLED registration in Dock.Resume.
    assertFalse(win:IsShown(), "the window stayed up into combat")
    assertTrue(NS.Dock.suspended)
    assertTrue(NS.Dock.wanted, "the combat hide keeps the wish")
    assertEqual(fakes.Dialogs.__count("CloseAll"), 0, "the combat suspend closed the dialogs (O30)")
    M.__lockdown = false
    M.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(win:IsShown(), "the window did not come back after combat")
    assertFalse(NS.Dock.suspended)
end)

test("dock: the sheet's OnHide clears the wish, so the window does not come back on the next open", function()
    local NS, M, fakes, win = opened()
    M.__world:closeCharacter()
    assertFalse(win:IsShown())
    assertFalse(NS.Dock.wanted)
    assertEqual(fakes.Dialogs.__count("CloseAll"), 1)
    assertEqual(fakes.Dialogs.__calls[1][2], "host")
    M.__world:openCharacter()
    assertFalse(win:IsShown(), "the window reappeared on the next sheet open")
    -- The sheet closed DURING combat, while the window was already down for it: only the sheet's
    -- own hook can drop the wish (the window's OnHide ran at REGEN_DISABLED and kept it).
    NS.Dock.Open()
    M.__fire("PLAYER_REGEN_DISABLED")
    M.__lockdown = true
    M.__world:closeCharacter()
    M.__lockdown = false
    M.__fire("PLAYER_REGEN_ENABLED")
    M.__world:openCharacter()
    -- red under: drop `Dock.wanted = false` from the sheet's OnHide hook.
    assertFalse(win:IsShown(), "a sheet closed in combat brought the window back on its next open")
end)

test("dock: the window takes ONE UIParent-relative SetPoint, and falls back to the holder when refused", function()
    local NS, M, _, win = opened()
    assertEqual(#win.__pts, 1, "one SetPoint per attach")
    local p = win.__pts[1]
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], M.UIParent); assertEqual(p[3], "BOTTOMLEFT")
    assertEqual(p[4], 300); assertEqual(p[5], 500)
    -- The corner did not move: the follow re-issues nothing.
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    assertEqual(#win.__pts, 1)
    -- The client refuses the anchor (a protected child): the window parks in the holder, follow off.
    rawset(win, "SetPoint", function() error("Cannot anchor protected frames to regions") end)
    rawset(M.CharacterFrame, "GetRight", function() return 320 end)
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    -- red under: call PositionWindow without pcall in Dock.Attach (the tick raises).
    assertTrue(NS.Dock.followDisabled)
    assertEqual(win:GetParent(), M.OutfitterRebornSheetHolder)
end)

-- The drawer follows the window (modules/QuickSlots.lua). A window parked in the holder is hidden by
-- its parent, after which its own Hide fires nothing in the client, so the sheet's OnHide syncs too.
test("dock: closing the sheet syncs the drawer after the window is gone", function()
    local NS, M, _, win = opened()
    local seen = {}
    local real = NS.QuickSlots.DrawerSync
    NS.QuickSlots.DrawerSync = function(...)
        seen[#seen + 1] = win:IsVisible() == true
        return real(...)
    end
    -- The client's hide through the parent: the window's OnHide runs, its own shown flag still set.
    win:__fire("OnHide")
    rawset(win, "Hide", function(self) rawset(self, "__shown", false) end)
    M.__world:closeCharacter()
    NS.QuickSlots.DrawerSync = real
    -- red under: no DrawerSync in the sheet's OnHide (the window's own hide fired nothing).
    assertTrue(#seen >= 2, "the sheet's hide did not sync the drawer")
    assertFalse(seen[#seen], "the last sync ran while the window was still visible")
    assertFalse(NS.Dock.IsVisible(), "Dock.IsVisible answers a window under a hidden sheet")
end)

test("dock: a sheet that was never laid out parks the window at the UIParent TOPLEFT", function()
    local NS, M = scene()
    M.__world:openCharacter()
    NS.Dock.Open()
    local win = M.OutfitterRebornWindow
    local p = win.__pts[#win.__pts]
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], M.UIParent); assertEqual(p[3], "TOPLEFT")
end)

test("dock: the follow runs every 0.05 s on the driver frame, only while shown and standing up", function()
    local NS, M, _, win = opened()
    local driver = M.OutfitterRebornDockDriver
    assertTrue(driver.__scripts.OnUpdate ~= nil, "the follow is armed while the window is shown")
    rawset(M.CharacterFrame, "GetRight", function() return 350 end)
    driver:__fire("OnUpdate", 0.03)
    -- red under: drop the FOLLOW_INTERVAL throttle in the driver's OnUpdate.
    assertEqual(#win.__pts, 1, "the follow ran before 0.05 s")
    driver:__fire("OnUpdate", 0.03)
    assertEqual(#win.__pts, 2, "the moved corner was not followed")
    assertEqual(win.__pts[2][4], 350)
    -- Stood down: the tick does nothing (H26), and the window goes.
    NS.SetByPath("enabled", false)
    assertFalse(win:IsShown())
    assertNil(driver.__scripts.OnUpdate, "the follow survived the stand-down")
    NS.SetByPath("enabled", true)
    M.__world:openCharacter()
    NS.Dock.Open()
    assertTrue(win:IsShown())
    NS.Dock.Close()
    assertNil(driver.__scripts.OnUpdate, "the follow survived the window's hide")
end)

-- Wrap NS[mod][name] in a counter that calls straight through.
local function counted(NS, mod, name)
    local n, orig = { count = 0 }, NS[mod][name]
    NS[mod][name] = function(...)
        n.count = n.count + 1
        return orig(...)
    end
    return n
end

test("dock: an idle States poll sends no STACK_CHANGED, and a stack change keeps the status cache", function()
    local NS, M = opened()
    NS.Outfits.Create("Idle", { HeadSlot = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot")) })
    local driver = M.OutfitterRebornDockDriver
    local function followTick() driver:__fire("OnUpdate", 0.06) end
    for _ = 1, 4 do M.__fireTimers() end
    followTick()
    -- The States poll: the one armed 0.5 s repeater (POLL_PERIOD, modules/States.lua). Its ticks are
    -- counted, so zero announcements after zero ticks cannot pass.
    local poll
    for _, h in ipairs(M.__timers()) do
        if type(h) == "table" and h.looping and h.delay == 0.5 then poll = h end
    end
    assertTrue(poll ~= nil, "the fixture needs the States poll armed")
    local ticks, pollFn = 0, poll.func
    poll.func = function(...)
        ticks = ticks + 1
        return pollFn(...)
    end
    local sent = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.STACK_CHANGED, function() sent = sent + 1 end)
    local builds = counted(NS, "WindowListModel", "Build")
    for _ = 1, 10 do
        M.__fireTimers()
        followTick()
    end
    assertTrue(ticks >= 10, "the poll ticked " .. ticks .. " times")
    -- red under: reverting C-01's st.touched gate (flush in modules/Equip.lua sending unconditionally).
    assertEqual(sent, 0, "an idle bracket announced STACK_CHANGED")
    assertEqual(builds.count, 0, "the idle window rebuilt its list")
    -- A real stack change redraws the worn marks but keeps the inventory-driven status.
    local statuses = counted(NS, "Outfits", "Status")
    NS.SendBus(NS.MSG.STACK_CHANGED)
    followTick()
    assertEqual(builds.count, 1, "a stack change did not redraw the list")
    -- red under: Win.Install's STACK_CHANGED receiver in modules/Window.lua calling MarkDirty(true).
    assertEqual(statuses.count, 0, "a stack change wiped the status cache")
end)

test("dock: a stood-down tick returns before it reads the sheet (the latch first)", function()
    local NS, M = opened()
    local driver = M.OutfitterRebornDockDriver
    local tick = driver.__scripts.OnUpdate
    local reads = 0
    rawset(M.CharacterFrame, "GetRight", function() reads = reads + 1; return 300 end)
    NS.lifecycle:Hold("test")
    -- red under: drop the `if NS.IsStoodDown() then return end` from the driver's OnUpdate.
    tick(driver, 1)
    assertEqual(reads, 0, "a stood-down follow read the sheet")
    NS.lifecycle:Release("test")
end)

test("dock: the window is in UISpecialFrames, by its global name", function()
    local _, M = opened()
    local found = false
    for _, name in ipairs(M.UISpecialFrames) do
        if name == "OutfitterRebornWindow" then found = true end
    end
    assertTrue(found, "Escape does not close the window")
end)

test("dock: Open shows the sheet first when it is hidden, and Toggle closes the window", function()
    local NS, M = scene()
    assertFalse(M.PaperDollFrame:IsShown())
    -- red under: drop the ToggleCharacter call from Dock.Open.
    NS.Dock.Open()
    assertTrue(M.CharacterFrame:IsShown() and M.PaperDollFrame:IsShown(), "Open did not show the sheet")
    assertTrue(NS.Dock.IsShown())
    NS.Dock.Toggle()
    assertFalse(NS.Dock.IsShown())
    assertTrue(M.PaperDollFrame:IsShown(), "Toggle closed the sheet")
    NS.Dock.Toggle()
    assertTrue(NS.Dock.IsShown())
end)

test("dock: Toggle(true), the launcher's, closes the sheet with the window; the dialogs close once", function()
    local NS, M, fakes = opened()
    NS.Dock.Toggle(true)
    assertFalse(NS.Dock.IsShown())
    -- red under: Dock.Toggle ignoring closeSheet (Outfitter.lua:6699-6708 hid CharacterFrame too).
    assertFalse(M.PaperDollFrame:IsShown(), "the sheet stayed open")
    -- red under: the sheet's OnHide closing the dialogs again after the window's OnHide did.
    assertEqual(fakes.Dialogs.__count("CloseAll"), 1)
    NS.Dock.Toggle(true)
    assertTrue(NS.Dock.IsShown() and M.PaperDollFrame:IsShown(), "an open shows the sheet and the window")
end)

test("dock: closing the window (Close, Escape) closes the dialogs; only the combat suspend keeps them", function()
    local NS, M, fakes, win = opened()
    NS.Dock.Close()
    -- red under: onWindowHide without NS.Dialogs.CloseAll (Outfitter.lua:1491-1504 canceled both dialogs).
    assertEqual(fakes.Dialogs.__count("CloseAll"), 1)
    assertEqual(fakes.Dialogs.__calls[1][2], "host")
    NS.Dock.Open()
    win:Hide()                                           -- Escape: UISpecialFrames hides it directly
    assertEqual(fakes.Dialogs.__count("CloseAll"), 2, "Escape is a close")
    assertTrue(M.PaperDollFrame:IsShown(), "Escape closed the window only")
end)

test("dock: the window's OnHide clears the selection and closes the menu and the icon browser", function()
    local NS, M, fakes = opened()
    local id = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    NS.Stack.Select(id)
    NS.Dock.Close()
    assertNil(NS.Stack.Selected())
    assertEqual(fakes.IconBrowser.__count("Close"), 1)
    assertEqual(fakes.IconBrowser.__calls[1][2], "opener")
    assertFalse(NS.Dock.IsShown())
    assertTrue(M.PaperDollFrame:IsShown(), "closing the window closed the sheet")
end)

test("browser: closing the window or the sheet closes the browser", function()
    local NS, M = opened()
    local id = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    assertTrue(NS.IconBrowser.Open(id))
    NS.Dock.Close()
    -- red under: onWindowHide without NS.IconBrowser.Close (a browser over a closed window).
    assertFalse(NS.IconBrowser.IsOpen(), "closing the window left the browser open")
    NS.Dock.Open()
    assertTrue(NS.IconBrowser.Open(id))
    M.__world:closeCharacter()
    assertFalse(NS.IconBrowser.IsOpen(), "closing the sheet left the browser open")
end)

test("dock: a stand-down hides the window and the sheet button; a stand-up shows the button", function()
    local NS, M, _, win = opened()
    NS.SetByPath("enabled", false)
    assertFalse(win:IsShown())
    assertFalse(M.OutfitterRebornSheetButton:IsShown())
    -- A show request while down is refused by the decision itself.
    NS.Dock.Open()
    assertFalse(win:IsShown())
    NS.SetByPath("enabled", true)
    assertTrue(M.OutfitterRebornSheetButton:IsShown())
end)

test("dock: the footer's New outfit opens the outfit dialog, the title-strip button the settings", function()
    local NS, M, fakes = opened()
    local opened_ = 0
    NS.OpenOptionsPanel = function() opened_ = opened_ + 1 end
    M.OutfitterRebornNewOutfitButton:__fire("OnClick", "LeftButton")
    assertEqual(fakes.OutfitDialog.__count("OpenNew"), 1)
    M.OutfitterRebornWindowSettings:__fire("OnClick", "LeftButton")
    assertEqual(opened_, 1)
end)

test("dock: no file in modules/ names a strata literal (frame-layering-§5)", function()
    local hits = {}
    for _, rel in ipairs(T.Loader.tocFiles(T.root .. "/OutfitterReborn.toc")) do
        if rel:find("^modules/") then
            local f = assert(io.open(T.root .. "/" .. rel, "rb"))
            local n = 0
            for line in f:lines() do
                n = n + 1
                if line:find('SetFrameStrata("', 1, true) then hits[#hits + 1] = rel .. ":" .. n end
            end
            f:close()
        end
    end
    -- red under: write win:SetFrameStrata("MEDIUM") anywhere in modules/.
    assertEqual(#hits, 0, table.concat(hits, "\n"))
end)

-- ── the sheet button and the flush dock (sheet and window feedback design G1-G3, plan Task 3.2) ──

-- The last SetPoint the sheet button was given.
local function buttonPoint(M)
    local pts = M.OutfitterRebornSheetButton.__pts
    return pts[#pts]
end

-- Record the last SetSize `frame` is given (the base mock keeps no size; fidelity rule 2).
local function recordSize(frame)
    local sized = {}
    rawset(frame, "SetSize", function(_, w, h) sized.w, sized.h = w, h end)
    return sized
end

test("dock: the sheet button sits right of the Equipment Manager tab", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local _, M = scene()
    local sized = recordSize(M.OutfitterRebornSheetButton)
    M.__world:openCharacter()
    local p = buttonPoint(M)
    -- red under: keep the old anchor, RIGHT of CharacterFrameCloseButton -2 (G1: it sat by the close X),
    -- or the square LEFT/RIGHT one before smoke round 2 (design G2: bottoms on the tabs' line).
    assertEqual(p[1], "BOTTOMLEFT"); assertEqual(p[2], M.PaperDollSidebarTab3); assertEqual(p[3], "BOTTOMRIGHT")
    assertEqual(p[4], 4); assertEqual(p[5], 0)
    assertEqual(sized.w, 33); assertEqual(sized.h, 35)
end)

test("dock: on EllesmereUI the button is a label above the Equipment label", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local _, M = scene()
    local tab = M.__sheets.eui()
    M.__loadedAddOns.EllesmereUIBlizzardSkin = true
    local sized = recordSize(M.OutfitterRebornSheetButton)
    -- red under: anchor the button once at build instead of on every sheet show (the kind is re-read).
    M.__world:openCharacter()
    local p = buttonPoint(M)
    assertEqual(p[1], "BOTTOM"); assertEqual(p[2], tab); assertEqual(p[3], "TOP")
    assertEqual(p[4], 0); assertEqual(p[5], 0)
    assertEqual(sized.w, 64); assertEqual(sized.h, 25)
end)

test("dock: the button is parented to CharacterFrame and above the close button's level", function()
    local _, M = scene()
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    -- red under: parent it to the sheet holder (PaperDollFrame shares CharacterFrame's level, and the
    -- frame's NineSlice at 500 and the close button at 510 draw over it: the stock-sheet bug of G1).
    assertEqual(button:GetParent(), M.CharacterFrame)
    assertTrue(button:GetFrameLevel() > M.CharacterFrameCloseButton:GetFrameLevel(),
        "the button sits under the close button's level")
end)

test("dock: the button shows with the paper doll and hides with it", function()
    local _, M = scene()
    local button = M.OutfitterRebornSheetButton
    M.__world:openCharacter()
    assertTrue(button:IsShown())
    -- The Reputation or Currency tab hides PaperDollFrame but not CharacterFrame, the button's parent.
    -- red under: drop the button's Hide from the sheet's OnHide hook.
    M.PaperDollFrame:Hide(); M.PaperDollFrame:__fire("OnHide")
    assertFalse(button:IsShown(), "the button stayed up off the paper doll")
    M.PaperDollFrame:Show(); M.PaperDollFrame:__fire("OnShow")
    assertTrue(button:IsShown())
end)

test("dock: the button's icon is the default outfit icon, the gold tint retired", function()
    local NS, M = scene()
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    -- Smoke round 2 design G1 (D1): 132724, cropped as item art is, untinted.
    -- red under: the coat hanger, tinted with SHEET_BUTTON_TINT / of.sheet.button.
    assertEqual(button.icon:GetTexture(), 132724)
    assertNil(NS.Constants.SHEET_BUTTON_TINT, "the retired tint constant is still published")
    local r, g, b = button.icon:GetVertexColor()
    assertTrue(r == 1 and g == 1 and b == 1, "the icon is tinted")
    local l, t, _, bottom, right = button.icon:GetTexCoord()
    assertTrue(near(l, 0.07) and near(t, 0.07) and near(right, 0.93) and near(bottom, 0.93), "the icon is not cropped")
end)

-- ── the host's look (smoke round 2 design G2, D3/D4) ──────────────────────────────────────────

-- PaperDollSidebarTabTemplate's art (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/
-- Mainline/PaperDollFrame.xml:393-430) and its selected TabBg (PaperDollFrame.lua:2678-2692).
local SIDEBAR_TABS = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs"
local TAB_BG = { 0.015625, 0.796875, 0.61328125, 0.78125 }
local TAB_BG_SELECTED = { 0.015625, 0.796875, 0.7890625, 0.95703125 }
local HIDER = { 0.015625, 0.546875, 0.11328125, 0.1875 }
local HIGHLIGHT = { 0.015625, 0.5, 0.1953125, 0.31640625 }

-- A texture's left, right, top, bottom, from the mock's four corners.
local function coords(tex)
    local l, t, _, b, r = tex:GetTexCoord()
    return { l, r, t, b }
end

local function assertCoords(tex, want, what)
    local got = coords(tex)
    for i = 1, 4 do
        assertTrue(near(got[i], want[i]), ("%s coord %d: %s, want %s"):format(what, i, tostring(got[i]), tostring(want[i])))
    end
end

local function assertTabLook(button, selected)
    assertEqual(button.TabBg:GetTexture(), SIDEBAR_TABS)
    assertEqual((button.TabBg:GetDrawLayer()), "BACKGROUND")
    assertEqual(button.TabBg:GetWidth(), 50); assertEqual(button.TabBg:GetHeight(), 43)
    local p = { button.TabBg:GetPoint(1) }
    assertEqual(p[1], "BOTTOMLEFT"); assertEqual(p[4], -9); assertEqual(p[5], -2)
    assertTrue(button.TabBg:IsShown(), "the tab background is hidden")
    assertTrue(button.icon:IsShown(), "the tab's icon is hidden")
    assertEqual(button.Hider:GetTexture(), SIDEBAR_TABS)
    assertEqual((button.Hider:GetDrawLayer()), "OVERLAY")
    assertCoords(button.Hider, HIDER, "Hider")
    assertEqual(button.Highlight:GetTexture(), SIDEBAR_TABS)
    assertEqual((button.Highlight:GetDrawLayer()), "HIGHLIGHT")
    assertCoords(button.Highlight, HIGHLIGHT, "Highlight")
    assertFalse(button.label:IsShown(), "the EllesmereUI label shows on a tab")
    if selected then
        assertCoords(button.TabBg, TAB_BG_SELECTED, "the selected TabBg")
        assertFalse(button.Hider:IsShown(), "a selected tab keeps its Hider")
        assertFalse(button.Highlight:IsShown(), "a selected tab keeps its Highlight")
    else
        assertCoords(button.TabBg, TAB_BG, "TabBg")
        assertTrue(button.Hider:IsShown(), "an unselected tab has no Hider")
        assertTrue(button.Highlight:IsShown(), "an unselected tab has no Highlight")
    end
end

test("dock: on the stock sheet the button is a sidebar tab, selected while the window shows", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    -- red under: the borderless skinned icon (no TabBg, Hider or Highlight).
    assertTabLook(button, false)
    NS.Dock.Open()
    assertTrue(NS.Dock.IsShown())
    -- red under: no selected state (the tab keeps the unselected art while the window is open).
    assertTabLook(button, true)
    NS.Dock.Close()
    assertTabLook(button, false)
end)

test("dock: on Chonky the button is the same sidebar tab", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local _, M = scene()
    M.__sheets.chonky()
    M.__loadedAddOns.ChonkyCharacterSheet = true
    M.__world:openCharacter()
    assertTabLook(M.OutfitterRebornSheetButton, false)
end)

-- Smoke round 3 E10 (29.png Chonky, 30.png stock): the icon is the neighbors' size and on their
-- center, inside TabBg's bevel. The neighbors' pictures in PaperDollSidebarTabs are 25-26 wide
-- (alpha > 0.5) and center where the template's Icon does; TabBg's bevel lines run at tab x 2 and 32
-- and y 31-32, so its face is x 3..32, y 1..31 (the file's texels, 1:1 with the tab's units).
local TAB_FACE = { left = 3, right = 32, bottom = 1, top = 31 }

local function assertTabIcon(NS, button, dx, dy)
    local icon = button.icon
    assertEqual((icon:GetDrawLayer()), "ARTWORK")
    local w, h = icon:GetSize()
    assertEqual(w, 26, "the icon's width"); assertEqual(h, 26, "the icon's height")
    local p = { icon:GetPoint(1) }
    assertEqual(p[1], "CENTER"); assertEqual(p[2], button); assertEqual(p[3], "CENTER")
    assertEqual(p[4], dx, "the icon's x offset"); assertEqual(p[5], dy, "the icon's y offset")
    local _, _, _, _, _, bw, bh = NS.Sheet.ButtonAnchor()
    local cx, cy = bw / 2 + p[4], bh / 2 + p[5]
    assertTrue(cx - w / 2 >= TAB_FACE.left and cx + w / 2 <= TAB_FACE.right, "the icon covers TabBg's side bevel")
    assertTrue(cy - h / 2 >= TAB_FACE.bottom and cy + h / 2 <= TAB_FACE.top, "the icon covers TabBg's top bevel")
end

test("dock: the tab's icon is the neighbors' size, on their center, inside the bevel", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    -- red under: round 2's 30 x 30 CENTER 0,0 (over the bevel, 2 above the neighbors' center).
    assertTabIcon(NS, M.OutfitterRebornSheetButton, 1, -2)
end)

test("dock: the tab's icon follows the neighbor's icon, read on each sheet show", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    M.__world:openCharacter()
    assertTabIcon(NS, M.OutfitterRebornSheetButton, 1, -2)
    M.__world:closeCharacter()
    -- A skin re-anchors the neighbor's icon between two opens: the next open follows it.
    local tab3 = M.PaperDollSidebarTab3
    tab3.Icon:ClearAllPoints()
    tab3.Icon:SetPoint("BOTTOM", tab3, "BOTTOM", 2, -3)
    M.__world:openCharacter()
    -- red under: placeButton not re-anchoring the icon from NS.Sheet.TabIconOffset (an icon anchored
    -- once, at the first placing, keeps the first open's offset).
    assertTabIcon(NS, M.OutfitterRebornSheetButton, 2, -3)
end)

test("dock: on Chonky the tab's icon sits as on the stock sheet", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    M.__sheets.chonky()
    M.__loadedAddOns.ChonkyCharacterSheet = true
    M.__world:openCharacter()
    assertTabIcon(NS, M.OutfitterRebornSheetButton, 1, -2)
end)

-- The EllesmereUI sheet with its Equipment label carrying EUI's font, and the accent `green`.
local function euiScene(green)
    local NS, M = scene()
    local tab = M.__sheets.eui()
    tab._text = tab:CreateFontString(nil, "OVERLAY")
    tab._text:SetFont("Fonts\\EUI.ttf", 10, "")
    M.EllesmereUI = { ELLESMERE_GREEN = green }
    M.__loadedAddOns.EllesmereUIBlizzardSkin = true
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    return NS, M, M.OutfitterRebornSheetButton
end

local function textColor(button)
    return ("%.3f %.3f %.3f %.2f"):format(button.label:GetTextColor())
end

test("dock: on EllesmereUI the button is a text label in EUI's tab style", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, button = euiScene({ r = 0.2, g = 0.8, b = 0.4 })
    -- red under: the tab look on EllesmereUI's sheet (TabBg and the icon over its text labels).
    assertTrue(button.label:IsShown(), "no label")
    assertEqual(button.label:GetText(), NS.L["Outfits"])
    local face, size, flags = button.label:GetFont()
    assertEqual(face, "Fonts\\EUI.ttf", "the label's face is not EUI's"); assertEqual(size, 10); assertEqual(flags, "")
    for _, key in ipairs({ "TabBg", "icon", "Hider", "Highlight" }) do
        assertFalse(button[key]:IsShown(), key .. " shows on EllesmereUI")
    end
    -- Idle white at 0.6, hover at 1, active in EllesmereUI's accent (_paintTopButton's rule).
    assertEqual(textColor(button), "1.000 1.000 1.000 0.60")
    button:__fire("OnEnter")
    assertEqual(textColor(button), "1.000 1.000 1.000 1.00")
    button:__fire("OnLeave")
    assertEqual(textColor(button), "1.000 1.000 1.000 0.60")
    NS.Dock.Open()
    assertTrue(NS.Dock.IsShown())
    assertEqual(textColor(button), "0.200 0.800 0.400 1.00")
    -- The accent is read at paint time: EllesmereUI updates its table in place.
    M.EllesmereUI.ELLESMERE_GREEN.r = 0.9
    button:__fire("OnLeave")
    assertEqual(textColor(button), "0.900 0.800 0.400 1.00")
    NS.Dock.Close()
    assertEqual(textColor(button), "1.000 1.000 1.000 0.60")
end)

test("dock: without EllesmereUI's accent the active label takes EUI's own fallback", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, _, button = euiScene(nil)
    NS.Dock.Open()
    -- EllesmereUIBlizzardSkin_CharacterSheet.lua _paintTopButton's fallback { 0.51, 0.784, 1 }.
    assertEqual(textColor(button), "0.510 0.784 1.000 1.00")
end)

test("dock: the sheet button's label has a face before its text is set", function()
    -- The client raises "Font not set" on SetText for a FontString made with no template and no
    -- font yet; the mock stores the text regardless, so this scene models the client's refusal on
    -- the sheet button's own font strings. red under: buildLooks setting the label's text with its
    -- face left to applyLook (which only runs on EllesmereUI's text look, after the build).
    local refused = {}
    local _, M = scene({ mutate = function(Mk)
        local prev = Mk.CreateFrame
        Mk.CreateFrame = function(kind, name, parent, template)
            local f = prev(kind, name, parent, template)
            if name ~= "OutfitterRebornSheetButton" or type(f) ~= "table" then return f end
            local make = f.CreateFontString
            rawset(f, "CreateFontString", function(self, n, layer, tpl)
                local fs = make(self, n, layer, tpl)
                local setText = fs.SetText
                rawset(fs, "SetText", function(s, v)
                    if tpl == nil and s:GetFont() == nil and s:GetFontObject() == nil then
                        refused[#refused + 1] = v
                    end
                    return setText(s, v)
                end)
                return fs
            end)
            return f
        end
    end })
    M.__world:openCharacter()
    assertTrue(M.OutfitterRebornSheetButton ~= nil, "no sheet button")
    assertEqual(#refused, 0, "SetText on a font string with no font (the client's \"Font not set\")")
end)

test("dock: a sheet kind that changes after the show re-places and re-looks the button", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local _, M = scene()
    M.__loadedAddOns.EllesmereUIBlizzardSkin = true
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    assertTabLook(button, false)
    -- EllesmereUI builds its labels from a CharacterFrame OnShow hook after ours: the next frame.
    local tab = M.__sheets.eui()
    M.__fireTimers()
    -- red under: recheckSheet re-anchoring without the look (the tab art floats over the labels).
    local p = buttonPoint(M)
    assertEqual(p[2], tab)
    assertTrue(button.label:IsShown(), "the label did not follow the kind change")
    assertFalse(button.TabBg:IsShown(), "the tab art stayed up over EllesmereUI's labels")
end)

test("dock: the button is placed and shown in combat: it is a plain, insecure button", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local _, M = scene()
    local button = M.OutfitterRebornSheetButton
    -- The mock protects a Secure* frame by installing its own IsProtected (tests/mock_world.lua).
    assertNil(rawget(button, "IsProtected"), "the sheet button is a protected frame")
    local blocked = #M.__blocked
    M.__lockdown = true
    M.__world:openCharacter()
    assertTrue(button:IsShown(), "the button was not shown in combat")
    assertEqual(buttonPoint(M)[2], M.PaperDollSidebarTab3)
    assertTabLook(button, false)
    assertEqual(#M.__blocked, blocked, "a protected call was blocked")
    M.__lockdown = false
end)

test("dock: the window's top is flush with the sheet's top", function()
    local NS, M, _, win = opened()
    assertEqual(NS.Dock.Y_OFFSET, 0)
    local p = win.__pts[#win.__pts]
    -- red under: Y_OFFSET back at -30 (the window hung 30 px below the sheet's top).
    assertEqual(p[4], 300); assertEqual(p[5], 500)
    -- The sheet at another scale: its edges are converted into the window's units.
    rawset(M.CharacterFrame, "GetEffectiveScale", function() return 0.8 end)
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    rawset(M.CharacterFrame, "GetTop", function() return 510 end)
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    p = win.__pts[#win.__pts]
    assertEqual(p[4], 300 * 0.8); assertEqual(p[5], 510 * 0.8)
end)

test("dock: an open Chonky side panel pushes the window right", function()
    local NS, M = scene()
    local bg = M.__sheets.place(M.__sheets.chonky(), 400, 520)
    local mplus = M.__sheets.chonkyPanel("ccsm_sf", 700, 520)
    M.__loadedAddOns.ChonkyCharacterSheet = true
    M.__world:openCharacter()
    NS.Dock.Open()
    local win = M.OutfitterRebornWindow
    local p = win.__pts[#win.__pts]
    -- red under: positionWindow reading PaperDollFrame's corner instead of NS.Sheet.DockRight().
    assertEqual(p[4], 700, "the window sits on top of the open M+ panel")
    assertEqual(p[5], 520)
    -- The panel closes: the follow brings the window back to the backdrop's edge.
    mplus:Hide()
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    p = win.__pts[#win.__pts]
    assertEqual(p[4], 400)
    assertEqual(bg:IsShown(), true)
end)

test("dock: stood down, a sheet show neither shows nor re-anchors the button", function()
    local NS, M = scene()
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    local before = #button.__pts
    NS.SetByPath("enabled", false)
    M.__world:closeCharacter(); M.__world:openCharacter()
    -- red under: drop the latch from the sheet's OnShow hook.
    assertFalse(button:IsShown(), "the button came up while stood down")
    assertEqual(#button.__pts, before, "the button was re-anchored while stood down")
end)

-- ── the window's header chrome (sheet and window feedback design G10, plan Task 3.3) ──────────────

test("window: the close button is anchored at the header's top right", function()
    -- G10: NS.MakeCloseButton makes the x but anchors nothing, so a close with no point never drew.
    -- red under: drop the close's SetPoint from modules/Window.lua's titleStrip.
    local _, M, _, win = opened()
    local close = win.close
    assertTrue(close ~= nil, "the window keeps no close button (win.close)")
    local p = close.__pts[#close.__pts]
    assertTrue(p ~= nil, "the close button was never anchored")
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[2], win); assertEqual(p[3], "TOPRIGHT")
    assertEqual(p[4], -6); assertEqual(p[5], -5)
    assertTrue(M.OutfitterRebornWindowSettings ~= close, "the close is the settings button")
end)

test("window: the gear sits left of the close button", function()
    -- Both 18 px, both TOPRIGHT-anchored to the window: the gear's right edge (-28) clears the
    -- close's left edge (-6 - 18 = -24). red under: the gear moved onto the close's -6.
    local _, M, _, win = opened()
    local gear, close = M.OutfitterRebornWindowSettings, win.close
    local g, c = gear.__pts[#gear.__pts], close.__pts[#close.__pts]
    assertEqual(g[1], "TOPRIGHT"); assertEqual(g[2], win); assertEqual(g[3], "TOPRIGHT")
    assertEqual(g[4], -28); assertEqual(g[5], c[5])
    local CLOSE_SIZE = 18
    assertTrue(g[4] < c[4] - CLOSE_SIZE, "the gear overlaps the close button")
end)

local function rgb(tex) return ("%.3f %.3f %.3f"):format(tex:GetVertexColor()) end

test("window: the gear's art is the close X's size, centered, in the X's rest and hover tint", function()
    -- Smoke round 2 design G5 (D7): the gear drew 18 x 18 (SetAllPoints) against the X's 12 x 12.
    local _, M, _, win = opened()
    local gear, close = M.OutfitterRebornWindowSettings, win.close
    assertTrue(close.icon ~= nil, "the close has no art texture to measure")
    local art = close.icon:GetWidth()
    assertEqual(art, 12, "LibKa0s Core's CLOSE_ART")
    -- red under: gear.icon:SetAllPoints(gear) (the art fills the 18 px button).
    assertEqual(gear.icon:GetWidth(), art); assertEqual(gear.icon:GetHeight(), art)
    local p = { gear.icon:GetPoint(1) }
    assertEqual(p[1], "CENTER"); assertEqual(p[2], gear)
    -- red under: the gear left untinted (white) beside the X's gray, or no hover.
    local rest = rgb(close.icon)
    assertEqual(rgb(gear.icon), rest, "the gear's rest tint is not the X's")
    gear:__fire("OnEnter"); close:__fire("OnEnter")
    assertEqual(rgb(gear.icon), rgb(close.icon), "the gear's hover tint is not the X's")
    assertTrue(rgb(gear.icon) ~= rest, "the gear has no hover tint")
    gear:__fire("OnLeave"); close:__fire("OnLeave")
    assertEqual(rgb(gear.icon), rgb(close.icon), "the gear did not go back to the X's rest tint")
end)

test("window: without a close art texture the gear's art falls back to 12 px", function()
    local NS, M = scene()
    rawset(NS, "MakeCloseButton", function() return nil end)
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    local gear = M.OutfitterRebornWindowSettings
    assertEqual(gear.icon:GetWidth(), 12); assertEqual(gear.icon:GetHeight(), 12)
end)

-- ── the paper-doll pane across the sheet's tabs (review follow-up to Tasks 3.1-3.2) ──────────────
-- The button and the window belong to the paper doll: the Reputation and Currency tabs hide
-- PaperDollFrame, not CharacterFrame, and the Character tab shows it again.

local function toTab(M, doll)
    if doll then
        M.PaperDollFrame:Show(); M.PaperDollFrame:__fire("OnShow")
    else
        M.PaperDollFrame:Hide(); M.PaperDollFrame:__fire("OnHide")
    end
end

test("dock: switching to the Reputation tab on EllesmereUI does not re-anchor the button to stock", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    local tab = M.__sheets.eui()
    M.__loadedAddOns.EllesmereUIBlizzardSkin = true
    -- EllesmereUI's tab dispatcher: its PaperDollFrame OnShow hook shows the text tabs again, and it is
    -- installed at the first sheet open, after the dock's at login, so it runs second
    -- (EllesmereUIBlizzardSkin_CharacterSheet.lua:1044-1047, :1079-1090, :4907).
    M.PaperDollFrame:HookScript("OnShow", function() tab:Show() end)
    M.__world:openCharacter()
    NS.Dock.Open()
    local button = M.OutfitterRebornSheetButton
    assertEqual(buttonPoint(M)[2], tab)
    -- The Reputation tab: the doll hides, and EllesmereUI hides its tabs with it.
    toTab(M, false); tab:Hide()
    assertFalse(button:IsShown(), "the button stayed up on the Reputation tab")
    assertFalse(NS.Dock.IsShown(), "the window stayed up on the Reputation tab")
    -- red under: detect the EllesmereUI sheet by its tab being shown (it read "stock" here).
    assertEqual(NS.Sheet.Kind(), "eui")
    -- Back to the Character tab: the dock's hook runs while the EllesmereUI tab is still hidden.
    toTab(M, true)
    assertTrue(button:IsShown())
    local p = buttonPoint(M)
    assertEqual(p[2], tab, "the button went to the stock Equipment Manager tab")
    assertEqual(p[1], "BOTTOM"); assertEqual(p[4], 0)
end)

test("dock: a sheet tab built after the paper doll's OnShow is picked up on the next frame", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    M.__loadedAddOns.EllesmereUIBlizzardSkin = true
    M.__world:openCharacter()
    assertEqual(buttonPoint(M)[2], M.PaperDollSidebarTab3)
    -- EllesmereUI builds its tabs from a CharacterFrame OnShow hook on the first open
    -- (EllesmereUIBlizzardSkin_CharacterSheet.lua:4907, :3171), which may run after the doll's.
    local tab = M.__sheets.eui()
    -- red under: resolve the sheet kind only inside the doll's OnShow.
    M.__fireTimers()
    assertEqual(buttonPoint(M)[2], tab)
    -- Nothing changed: the next frame's check does not re-anchor again.
    local before = #M.OutfitterRebornSheetButton.__pts
    M.__world:closeCharacter(); M.__world:openCharacter()
    local after = #M.OutfitterRebornSheetButton.__pts
    M.__fireTimers()
    assertEqual(#M.OutfitterRebornSheetButton.__pts, after, "an unchanged kind was re-anchored")
    assertTrue(after > before)
    assertTrue(NS.Sheet.Kind() == "eui")
end)

test("dock: the next frame's sheet check does nothing once the doll is gone or stood down", function()
    local NS, M = scene()
    M.__loadedAddOns.EllesmereUIBlizzardSkin = true
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    M.__sheets.eui()
    toTab(M, false)
    local before = #button.__pts
    M.__fireTimers()
    assertEqual(#button.__pts, before, "re-anchored off the paper doll")
    assertFalse(button:IsShown(), "the check brought the button back off the paper doll")
    toTab(M, true)
    NS.SetByPath("enabled", false)
    before = #button.__pts
    M.__fireTimers()
    assertEqual(#button.__pts, before, "re-anchored while stood down")
    assertFalse(button:IsShown())
end)

test("dock: on Chonky the Reputation tab takes the button and window down, the Character tab brings them back", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = scene()
    M.__sheets.place(M.__sheets.chonky(), 400, 520)
    M.__loadedAddOns.ChonkyCharacterSheet = true
    M.__world:openCharacter()
    NS.Dock.Open()
    local button, win = M.OutfitterRebornSheetButton, M.OutfitterRebornWindow
    toTab(M, false)
    assertFalse(button:IsShown()); assertFalse(win:IsShown())
    -- Chonky's backdrop is CharacterFrame's and stays up on every tab (core/styles.lua:1090-1099).
    assertEqual(NS.Sheet.Kind(), "chonky")
    toTab(M, true)
    assertTrue(button:IsShown())
    assertEqual(buttonPoint(M)[2], M.PaperDollSidebarTab3)
end)

-- ── WoW Forever's sheet button: the outer side-tab strip (ruling D8, OR-F5) ─────────────────────
test("dock (Forever): the button sits below the last mode tab in the strip's look", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = scene()
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    local p = buttonPoint(M)
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], M.CharacterFrameModeTab6); assertEqual(p[3], "BOTTOMLEFT")
    assertEqual(button:GetParent(), M.CharacterFrame); assertTrue(button:IsShown())
    -- red under: Retail's hand-built sidebar art on Forever's strip.
    for _, key in ipairs({ "TabBg", "Hider", "Highlight", "label" }) do
        assertFalse(button[key]:IsShown(), key .. " shows on the side tab")
    end
    assertTrue(button.icon:IsShown(), "no template Icon, so the button's own icon draws")
    assertEqual(button.icon:GetTexture(), 132724)
end)

test("dock (Forever): with the client's template the button is a LargeSideTabButtonTemplate CheckButton", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = scene({ mutate = function(M)
        M.C_XMLUtil = { GetTemplateInfo = function(name)
            if name == "LargeSideTabButtonTemplate" then return { type = "CheckButton" } end
        end }
    end })
    local button = M.OutfitterRebornSheetButton
    -- red under: a plain Button with no template (Retail's), or the template on a Button.
    assertEqual(button.__frameType, "CheckButton"); assertEqual(button.__template, "LargeSideTabButtonTemplate")
    M.__world:openCharacter()
    button:__fire("OnClick")
    assertTrue(button:GetChecked(), "the click opened the window and the tab is checked")
    button:__fire("OnClick")
    assertFalse(button:GetChecked(), "the second click closed it")
end)

test("dock: on Retail the sheet button is a plain Button with no template", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local _, M = scene({ mutate = function(M) M.C_XMLUtil = { GetTemplateInfo = function() return {} end } end })
    local button = M.OutfitterRebornSheetButton
    -- red under: SIDE_TAB_TEMPLATE set for Retail.
    assertEqual(button.__frameType, "Button"); assertNil(button.__template)
end)
