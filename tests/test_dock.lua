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

-- The scene with the sheet laid out at (right 300, top 500) and the window open on it.
local function opened()
    local NS, M, fakes = scene()
    rawset(M.PaperDollFrame, "GetRight", function() return 300 end)
    rawset(M.PaperDollFrame, "GetTop", function() return 500 end)
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
    assertEqual(D.Y_OFFSET, -30); assertEqual(D.FOLLOW_INTERVAL, 0.05)
end)

test("dock: the holder fills the sheet, and the sheet button toggles the window", function()
    local NS, M = scene()
    local holder, button = M.OutfitterRebornSheetHolder, M.OutfitterRebornSheetButton
    assertEqual(holder:GetParent(), M.PaperDollFrame)
    assertEqual(button:GetParent(), holder)
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
    M.CharacterFrame:SetFrameStrata("HIGH")
    M.CharacterFrame:SetFrameLevel(20)
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    -- red under: copy a fixed strata (L.STRATA.HUD) in Dock.ApplyLayers instead of the host's.
    assertEqual(win:GetFrameStrata(), "HIGH")
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
    assertEqual(p[4], 300); assertEqual(p[5], 500 + NS.Dock.Y_OFFSET)
    -- The corner did not move: the follow re-issues nothing.
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    assertEqual(#win.__pts, 1)
    -- The client refuses the anchor (a protected child): the window parks in the holder, follow off.
    rawset(win, "SetPoint", function() error("Cannot anchor protected frames to regions") end)
    rawset(M.PaperDollFrame, "GetRight", function() return 320 end)
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
    rawset(M.PaperDollFrame, "GetRight", function() return 350 end)
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

test("dock: a stood-down tick returns before it reads the sheet (the latch first)", function()
    local NS, M = opened()
    local driver = M.OutfitterRebornDockDriver
    local tick = driver.__scripts.OnUpdate
    local reads = 0
    rawset(M.PaperDollFrame, "GetRight", function() reads = reads + 1; return 300 end)
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

test("dock: the window's OnHide clears the selection and closes the menu and the icon chooser", function()
    local NS, M, fakes = opened()
    local id = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    NS.Stack.Select(id)
    NS.Dock.Close()
    assertNil(NS.Stack.Selected())
    assertEqual(fakes.IconChooser.__count("Close"), 1)
    assertEqual(fakes.IconChooser.__calls[1][2], "opener")
    assertFalse(NS.Dock.IsShown())
    assertTrue(M.PaperDollFrame:IsShown(), "closing the window closed the sheet")
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
