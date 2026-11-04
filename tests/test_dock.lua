-- tests/test_dock.lua — P4.19 (design §7.0-§7.2, H4, INV §7.1, §16.1-§16.2): modules/Dock.lua, the
-- window's show model, follow and layer sync, and the sheet button.
--
-- The window is docked, never anchored: one UIParent-relative SetPoint, re-issued from a 0.05 s
-- follow on an owned driver frame. Its strata and level are the sheet holder's (level + DOCK_OVER_HOST),
-- written through NS.SecureQueue because it holds secure children. It is never shown during combat
-- lockdown: PLAYER_REGEN_DISABLED hides it, PLAYER_REGEN_ENABLED brings it back.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dock_scene.lua")(T)

local DOCK_OVER_HOST = 1
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
    local _, M = scene()
    local sized = recordSize(M.OutfitterRebornSheetButton)
    M.__world:openCharacter()
    local p = buttonPoint(M)
    -- red under: keep the old anchor, RIGHT of CharacterFrameCloseButton -2 (G1: it sat by the close X).
    assertEqual(p[1], "LEFT"); assertEqual(p[2], M.PaperDollSidebarTab3); assertEqual(p[3], "RIGHT")
    assertEqual(p[4], 4); assertEqual(p[5], 0)
    assertEqual(sized.w, 33); assertEqual(sized.h, 33)
end)

test("dock: on EllesmereUI the button follows the Equipment label", function()
    local _, M = scene()
    local tab = M.__sheets.eui()
    M.__loadedAddOns.EllesmereUIBlizzardSkin = true
    local sized = recordSize(M.OutfitterRebornSheetButton)
    -- red under: anchor the button once at build instead of on every sheet show (the kind is re-read).
    M.__world:openCharacter()
    local p = buttonPoint(M)
    assertEqual(p[1], "LEFT"); assertEqual(p[2], tab); assertEqual(p[3], "RIGHT")
    assertEqual(p[4], 2); assertEqual(p[5], 0)
    assertEqual(sized.w, 20); assertEqual(sized.h, 20)
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

test("dock: the button's icon is the coat hanger, tinted, with no border", function()
    local NS, M = scene()
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    local hanger = NS.Icon("ph:coat-hanger")
    assertTrue(hanger ~= nil, "ph:coat-hanger is not a shipped icon (the LibKa0s icons: line)")
    assertEqual(NS.Constants.DEFAULT_OUTFIT_ICON, hanger)
    -- red under: keep NS.Constants.LOGO_128 on the button.
    assertEqual(button.icon:GetTexture(), hanger)
    local tint = NS.Constants.SHEET_BUTTON_TINT
    local r, g, b = button.icon:GetVertexColor()
    -- red under: drop the icon token remap from the button's Skin.Button (the icon is drawn btn.icon gray).
    assertEqual(r, tint[1]); assertEqual(g, tint[2]); assertEqual(b, tint[3])
    -- No box and no border: tests/test_skin.lua holds the Skin.Button options (noBg, noBorder).
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
    assertEqual(p[4], 2)
end)

test("dock: a sheet tab built after the paper doll's OnShow is picked up on the next frame", function()
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
