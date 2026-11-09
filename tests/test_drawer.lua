-- tests/test_drawer.lua — modules/QuickSlots.lua's outward drawer: the flyout arrows shown and every
-- flyout opened away from the character while the paper doll shows (sheet and window feedback design
-- G8, smoke round 2 design G3; Forever smoke feedback S7 and S3). Split from tests/test_quickslots.lua
-- (the file budget), which keeps the flyout's lists, clicks and gates.

local T = _G.OUTFITTERREBORN_TEST
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local RETAIL_ONLY = "pins Retail's flyout stand-in (its anchors, coords and write counts); WoW Forever's outward drawer has its own cases (S7)"
local FOREVER_ONLY = "pins WoW Forever's outward drawer (ruling D4, Forever smoke feedback S7); runs on the forever kit profile"
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function QS(NS) return NS.QuickSlots end

-- ── the outward drawer (sheet and window feedback design G8) ─────────────────────────────────────
--
-- THE CLIENT STAND-IN. Blizzard's flyout as the drawer meets it, at wow-ui-source@297d7aa: each slot
-- button's popout arrow anchored once, `LEFT` -> slot `RIGHT` (-8, 0), with the unreversed coords
-- (Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1527-1532; the weapons are vertical, :1517-1524);
-- EquipmentFlyout_UpdateItems anchoring `flyout.buttonFrame` `TOPLEFT` -> arrow `TOPRIGHT` + (anchorX,
-- anchorY) with no ClearAllPoints (Blizzard_FrameXML/EquipmentFlyout.lua:331-339); and
-- EquipmentFlyoutPopoutButton_SetReversed's horizontal coord pairs (:633-651). Both functions are
-- globals the instance's hooksecurefunc really post-hooks by name. Smoke round 2 (design G3) adds the
-- arrows' visibility: each popout starts hidden (EquipmentFlyout.xml:26-37, hidden="true");
-- EquipmentFlyoutPopoutButton_HideAll unlocks a locked popout, hides the flyout and hides every arrow
-- (EquipmentFlyout.lua:598-612), and the Equipment Manager pane (PaperDollFrame.EquipmentManagerPane,
-- PaperDollFrame.lua:134) shows them all on its OnShow and calls HideAll on its OnHide (:2316-2319,
-- :2345-2346); EquipmentFlyout_Hide's OnHide clears the open popout's lock and reversal (:98-107).
-- The paper doll and the window are recorded fakes
-- (`state.visible`, NS.Dock.DollVisible, the drawer's gate since Forever smoke feedback S7, unless
-- `state.doll` says otherwise, and NS.Dock.IsVisible; `state.shown`, NS.Dock.IsShown, the tint's):
-- QuickSlots reads them at call time and owns no part of them.

local ARROW_FWD = { 0.15625, 0.5, 0.84375, 0.5, 0.15625, 0, 0.84375, 0 }      -- PaperDollFrame.lua:1527
local ARROW_BACK = { 0.15625, 0, 0.84375, 0, 0.15625, 0.5, 0.84375, 0.5 }     -- EquipmentFlyout.lua:644
local HL_FWD = { 0.15625, 1, 0.84375, 1, 0.15625, 0.5, 0.84375, 0.5 }        -- PaperDollFrame.lua:1528
local HL_BACK = { 0.15625, 0.5, 0.84375, 0.5, 0.15625, 1, 0.84375, 1 }       -- EquipmentFlyout.lua:645
local LEFT_COLUMN = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot",
                      "TabardSlot", "WristSlot" }

-- A region that records its points and counts its writes; hidden, with its shows and hides counted.
local function region(extra)
    local r = { pts = {}, writes = 0, shown = false, shows = 0, hides = 0 }
    function r:ClearAllPoints() self.pts = {}; self.writes = self.writes + 1 end
    function r:SetPoint(...) self.pts[#self.pts + 1] = { ... }; self.writes = self.writes + 1 end
    function r:Show() self.shown = true; self.shows = self.shows + 1 end
    function r:Hide() self.shown = false; self.hides = self.hides + 1 end
    function r:IsShown() return self.shown end
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

local function tex()
    local t = {}
    function t:SetTexCoord(...) self.coords = { ... } end
    return t
end

local function sameCoords(got, want, msg)
    assertEqual(table.concat(got or {}, ","), table.concat(want, ","), msg)
end

-- WoW Forever's flyout as F-UI draws it (wow-ui-source@9dc84f0, branch forever): each slot's
-- `flyoutDirection` (the left column RIGHT, the right column LEFT, the bottom row UP;
-- Camelot/PaperDollFrame.xml:136-165), the arrow 5 px off the slot by it (Camelot/PaperDollFrame.lua:
-- 1976-1989), RefreshVisualState turning its textures by it (Camelot/EquipmentFlyout.lua:707-755), no
-- SetReversed, and UpdateItems clearing buttonFrame and anchoring it by it (:420-433). Each slot has
-- a shown BorderFrame (Camelot/PaperDollFrame.xml:60).
local FOREVER_BOTTOM = { MainHandSlot = true, SecondaryHandSlot = true, RangedSlot = true }
local FOREVER_ROT = { LEFT = 0, RIGHT = math.pi, UP = 0, DOWN = math.pi }
local function foreverPopoutAnchor(popout, b, dir)
    popout:ClearAllPoints()
    if dir == "LEFT" then popout:SetPoint("RIGHT", b, "LEFT", -5, 0)
    elseif dir == "UP" then popout:SetPoint("BOTTOM", b, "TOP", 0, 5)
    else popout:SetPoint("LEFT", b, "RIGHT", 5, 0) end
end

local function foreverFlyout(M, flyout)
    local left = {}
    for _, slot in ipairs(LEFT_COLUMN) do left[slot] = true end
    for name, b in pairs(M.__slotButtons) do
        b.verticalFlyout = nil
        b.flyoutDirection = left[name] and "RIGHT" or FOREVER_BOTTOM[name] and "UP" or "LEFT"
        local border = { shown = true }
        function border:IsShown() return self.shown end
        rawset(b, "BorderFrame", border)
        local popout = b.popoutButton
        local textures = {}
        for _, key in ipairs({ "Normal", "Pushed", "Highlight" }) do
            local t = { rotation = nil }
            function t:SetRotation(r) self.rotation = r end
            function t.SetTexCoord() error("Forever's arrow is an atlas: no coords") end
            textures[key] = t
            popout["Get" .. key .. "Texture"] = function() return t end
        end
        foreverPopoutAnchor(popout, b, b.flyoutDirection)
        for _, t in pairs(textures) do t:SetRotation(FOREVER_ROT[b.flyoutDirection]) end
        popout.writes = 0
    end
    M.EquipmentFlyoutPopoutButton_SetReversed = nil
    M.EquipmentFlyoutPopoutButton_RefreshVisualState = function(popout)
        local r = FOREVER_ROT[popout:GetParent().flyoutDirection]
        popout:GetNormalTexture():SetRotation(r)
        popout:GetPushedTexture():SetRotation(r)
        popout:GetHighlightTexture():SetRotation(r)
    end
    M.EquipmentFlyout_Hide = function()
        local b = flyout.button
        flyout:Hide()
        if b and b.popoutButton then
            b.popoutButton.flyoutLocked = false
            M.EquipmentFlyoutPopoutButton_RefreshVisualState(b.popoutButton)
        end
        flyout.button = nil
    end
    M.EquipmentFlyout_UpdateItems = function()
        local b = flyout.button
        local rel = b.popoutButton or b
        local hs = b:GetParent().flyoutSettings
        local bf = flyout.buttonFrame
        bf:ClearAllPoints()
        local dir = b.flyoutDirection
        if dir == "LEFT" then bf:SetPoint("TOPRIGHT", rel, "TOPLEFT", -hs.anchorX, hs.anchorY)
        elseif dir == "UP" then bf:SetPoint("BOTTOMLEFT", rel, "TOPLEFT", hs.verticalAnchorX, -hs.verticalAnchorY)
        elseif dir == "DOWN" then bf:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", hs.verticalAnchorX, hs.verticalAnchorY)
        else bf:SetPoint("TOPLEFT", rel, "TOPRIGHT", hs.anchorX, hs.anchorY) end
    end
end

-- An instance with Blizzard's flyout stand-in and a fake window, the hooks built. `opts.drop` names
-- client functions the instance does not have.
local function drawerInstance(opts)
    opts = opts or {}
    local state = { shown = false, visible = false }
    local inst = unitLoad({ mutate = function(M)
        local fs = M.PaperDollItemsFrame.flyoutSettings
        fs.anchorX, fs.anchorY, fs.verticalAnchorX, fs.verticalAnchorY = 0, -3, 0, 0
        local flyout = M.CreateFrame("Frame", "EquipmentFlyoutFrame", M.UIParent)
        flyout:Hide()
        flyout.buttonFrame = region()
        for name, b in pairs(M.__slotButtons) do
            local vertical = name == "MainHandSlot" or name == "SecondaryHandSlot"
            local normal, highlight = tex(), tex()
            local popout = region({ GetNormalTexture = function() return normal end,
                                    GetHighlightTexture = function() return highlight end,
                                    GetParent = function() return b end })
            b.verticalFlyout = vertical or nil
            b.popoutButton = popout
            if vertical then
                popout:SetPoint("TOP", b, "BOTTOM", 0, 4)
            else
                popout:SetPoint("LEFT", b, "RIGHT", -8, 0)
                normal:SetTexCoord(unpack(ARROW_FWD)); highlight:SetTexCoord(unpack(HL_FWD))
            end
            popout.writes = 0
        end
        M.EquipmentFlyoutPopoutButton_SetReversed = function(popout, reversed)
            if popout:GetParent().verticalFlyout then return end
            popout:GetNormalTexture():SetTexCoord(unpack(reversed and ARROW_BACK or ARROW_FWD))
            popout:GetHighlightTexture():SetTexCoord(unpack(reversed and HL_BACK or HL_FWD))
        end
        -- EquipmentFlyout_Hide, with the flyout's OnHide (EquipmentFlyout.lua:98-107).
        M.EquipmentFlyout_Hide = function()
            local b = flyout.button
            flyout:Hide()
            if b and b.popoutButton then
                b.popoutButton.flyoutLocked = false
                M.EquipmentFlyoutPopoutButton_SetReversed(b.popoutButton, false)
            end
            flyout.button = nil
        end
        M.EquipmentFlyoutPopoutButton_HideAll = function()
            for _, b in pairs(M.__slotButtons) do
                if b.popoutButton.flyoutLocked then M.EquipmentFlyout_Hide() end
                b.popoutButton:Hide()
            end
        end
        M.EquipmentFlyoutPopoutButton_ShowAll = function()
            for _, b in pairs(M.__slotButtons) do b.popoutButton:Show() end
        end
        local pane = M.CreateFrame("Frame", nil, M.PaperDollFrame)
        pane:Hide()
        M.PaperDollFrame.EquipmentManagerPane = pane
        M.EquipmentFlyout_UpdateItems = function()
            local b = flyout.button
            local rel = b.popoutButton or b
            local hs = b:GetParent().flyoutSettings     -- the button's own host's (EquipmentFlyout.lua:244)
            if b.verticalFlyout then
                flyout.buttonFrame:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", hs.verticalAnchorX, hs.verticalAnchorY)
            else
                flyout.buttonFrame:SetPoint("TOPLEFT", rel, "TOPRIGHT", hs.anchorX, hs.anchorY)
            end
        end
        if FOREVER then foreverFlyout(M, flyout) end
        for _, name in ipairs(opts.drop or {}) do M[name] = nil end
        -- hooksecurefunc by name, as the client does it, on the two globals this stand-in defines;
        -- a missing global raises, as it does in the client.
        local base = M.hooksecurefunc
        M.hooksecurefunc = function(a, b, c)
            if type(a) == "string" then
                local orig = rawget(M, a)
                if type(orig) ~= "function" then error("hooksecurefunc(): " .. a .. " is not a function", 2) end
                rawset(M, a, function(...) orig(...); b(...) end)
                M.__hooks[#M.__hooks + 1] = { target = M, name = a }
                return
            end
            return base(a, b, c)
        end
    end })
    local NS, M = inst.NS, inst.mocks
    NS.Dock.IsShown = function() return state.shown end
    NS.Dock.IsVisible = function() return state.visible end
    NS.Dock.DollVisible = function()
        if state.doll ~= nil then return state.doll end
        return state.visible
    end
    QS(NS).Resume()
    return NS, M, state
end

local function arrowsShown(M)
    local n = 0
    for _, b in pairs(M.__slotButtons) do
        if b.popoutButton:IsShown() then n = n + 1 end
    end
    return n
end

-- The client opening the flyout on `slot`: the arrow locks and reverses, then the items are placed.
local function openFlyout(M, slot)
    local b = M.__slotButtons[slot]
    local flyout = M.EquipmentFlyoutFrame
    flyout.button = b
    flyout:Show()
    b.popoutButton.flyoutLocked = true
    if M.EquipmentFlyoutPopoutButton_SetReversed then
        M.EquipmentFlyoutPopoutButton_SetReversed(b.popoutButton, true)
    else
        M.EquipmentFlyoutPopoutButton_RefreshVisualState(b.popoutButton)
    end
    M.EquipmentFlyout_UpdateItems()
    return flyout.buttonFrame
end

-- The window opening or closing, as Dock's OnShow / OnHide hooks report it.
local function setWindow(NS, state, shown)
    state.shown, state.visible = shown, shown
    QS(NS).DrawerSync()
end

-- The buttonFrame's offset that puts the first item level with a slot `h` px tall (design G3):
-- BORDERWIDTH (3) - (h - EFITEM_HEIGHT (37)) / 2, EquipmentFlyout.lua:39, 44, 67.
local function levelY(h) return 3 - (h - 37) / 2 end
local GAP = 8          -- the arrow's visible half: 16 wide, 8 over the slot (PaperDollFrame.lua:1530-1532)

test("drawer: with the doll shown a left-column flyout's buttonFrame is anchored TOPRIGHT to the slot's TOPLEFT", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    -- red under: no EquipmentFlyout_UpdateItems post-hook (Blizzard's TOPLEFT -> TOPRIGHT stays).
    assertEqual(#bf.pts, 1, "the buttonFrame keeps one point, not Blizzard's and ours")
    local p = bf.pts[1]
    -- red under: the arrow as the anchor (the 2026-11-04 drawer: items 5.5 px below the slot's top).
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[2], M.__slotButtons.HeadSlot)
    assertEqual(p[3], "TOPLEFT"); assertEqual(p[4], -GAP); assertEqual(p[5], levelY(37))
end)

test("drawer: a right-column flyout's first item is level with its slot, past the arrow", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local legs = M.__slotButtons.LegsSlot
    legs:__setGeom(37, 40)
    local bf = openFlyout(M, "LegsSlot")
    assertEqual(#bf.pts, 1, "the buttonFrame keeps one point, not Blizzard's and ours")
    local p = bf.pts[1]
    -- red under: the G8 rule 'the right column is never touched' (Blizzard's arrow-relative point).
    assertEqual(p[1], "TOPLEFT"); assertEqual(p[2], legs); assertEqual(p[3], "TOPRIGHT")
    assertEqual(p[4], GAP); assertEqual(p[5], levelY(40))
end)

test("drawer: a left-column flyout on a taller slot is level with it too", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    M.__slotButtons.ChestSlot:__setGeom(37, 40)
    local p = openFlyout(M, "ChestSlot").pts[1]
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[4], -GAP); assertEqual(p[5], levelY(40))
end)

test("drawer: with the doll shown the left-column arrows sit on the slot's left, mirrored", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    for _, slot in ipairs(LEFT_COLUMN) do
        local b = M.__slotButtons[slot]
        local popout = b.popoutButton
        assertEqual(#popout.pts, 1, slot)
        local p = popout.pts[1]
        assertEqual(p[1], "RIGHT", slot); assertEqual(p[2], b, slot); assertEqual(p[3], "LEFT", slot)
        assertEqual(p[4], 8, slot); assertEqual(p[5], 0, slot)
        sameCoords(popout:GetNormalTexture().coords, ARROW_BACK, slot .. ": the arrow points left")
        sameCoords(popout:GetHighlightTexture().coords, HL_BACK, slot)
    end
end)

test("drawer: a right-column arrow stays where Blizzard put it, the flyout beside the slot", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local hands = M.__slotButtons.HandsSlot
    assertEqual(hands.popoutButton.writes, 0, "a right-column arrow was moved")
    local bf = openFlyout(M, "HandsSlot")
    assertEqual(#bf.pts, 1)
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][2], hands); assertEqual(bf.pts[1][3], "TOPRIGHT")
    assertEqual(bf.pts[1][4], GAP); assertEqual(bf.pts[1][5], levelY(37))
    sameCoords(hands.popoutButton:GetNormalTexture().coords, ARROW_BACK, "Blizzard's own reversed arrow")
end)

test("drawer: a moved right-column flyout gets Blizzard's own point back when the doll hides", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local hands = M.__slotButtons.HandsSlot
    local bf = openFlyout(M, "HandsSlot")
    hands.popoutButton.flyoutLocked = false       -- a hover-opened flyout: no lock, so it stays open
    setWindow(NS, state, false)
    -- red under: no restore of a moved right-column buttonFrame (our slot-relative point would stay).
    assertEqual(#bf.pts, 1)
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][2], hands.popoutButton)
    assertEqual(bf.pts[1][3], "TOPRIGHT"); assertEqual(bf.pts[1][4], 0); assertEqual(bf.pts[1][5], -3)
    assertTrue(M.EquipmentFlyoutFrame:IsShown(), "an unlocked flyout is not closed")
end)

test("drawer: the weapons' flyout opens down as Blizzard has it", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local bf = openFlyout(M, "MainHandSlot")
    assertEqual(bf.writes, 1)
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][3], "BOTTOMLEFT")
    assertEqual(M.__slotButtons.MainHandSlot.popoutButton.writes, 0, "the drawer moved a weapon's arrow")
end)

test("drawer: a right-column flyout after a left one drops the left one's anchor", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    openFlyout(M, "HeadSlot")
    local bf = openFlyout(M, "HandsSlot")
    -- red under: no restore of a moved buttonFrame (Blizzard's TOPLEFT would join our TOPRIGHT).
    assertEqual(#bf.pts, 1, "two points stretch the flyout")
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][2], M.__slotButtons.HandsSlot)
end)

test("drawer: another host's flyout after a left-column one keeps that host's own anchor", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    -- The Item Upgrade frame shares EquipmentFlyoutFrame with its own flyoutSettings (20, -8)
    -- (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_ItemUpgradeUI/Mainline/Blizzard_ItemUpgradeUI.lua:917-922),
    -- read off the button's parent (Blizzard_FrameXML/EquipmentFlyout.lua:244).
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    openFlyout(M, "HeadSlot")
    local host = M.CreateFrame("Frame", nil, M.UIParent)
    host.flyoutSettings = { anchorX = 20, anchorY = -8 }
    local upgrade = M.CreateFrame("Button", nil, host)
    local flyout = M.EquipmentFlyoutFrame
    flyout.button = upgrade
    M.EquipmentFlyout_UpdateItems()
    local bf = flyout.buttonFrame
    -- red under: the restore reading PaperDollItemsFrame.flyoutSettings (0, -3) for every button.
    assertEqual(#bf.pts, 1, "two points stretch the flyout")
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][2], upgrade); assertEqual(bf.pts[1][3], "TOPRIGHT")
    assertEqual(bf.pts[1][4], 20); assertEqual(bf.pts[1][5], -8)
end)

test("drawer: SetReversed on a left-column arrow mirrors its coords", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local popout = M.__slotButtons.ChestSlot.popoutButton
    M.EquipmentFlyoutPopoutButton_SetReversed(popout, true)
    -- red under: no SetReversed post-hook (Blizzard's reversed coords, pointing right, would stay).
    sameCoords(popout:GetNormalTexture().coords, ARROW_FWD, "reversed and mirrored points right")
    sameCoords(popout:GetHighlightTexture().coords, HL_FWD)
    M.EquipmentFlyoutPopoutButton_SetReversed(popout, false)
    sameCoords(popout:GetNormalTexture().coords, ARROW_BACK, "unreversed and mirrored points left")
    local legs = M.__slotButtons.LegsSlot.popoutButton
    M.EquipmentFlyoutPopoutButton_SetReversed(legs, true)
    sameCoords(legs:GetNormalTexture().coords, ARROW_BACK, "a right-column arrow keeps Blizzard's coords")
end)

test("drawer: with the doll hidden the flyout keeps Blizzard's anchors", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local _, M = drawerInstance()
    local bf = openFlyout(M, "HeadSlot")
    -- red under: drop the window check from the drawer's gate.
    assertEqual(bf.writes, 1, "the drawer moved the flyout with the doll hidden")
    assertEqual(bf.pts[1][1], "TOPLEFT")
    local popout = M.__slotButtons.HeadSlot.popoutButton
    assertEqual(popout.writes, 0)
    assertEqual(popout.shows + popout.hides, 0, "the drawer showed or hid an arrow with the doll hidden")
    sameCoords(popout:GetNormalTexture().coords, ARROW_BACK, "Blizzard's own reversed arrow")
end)

test("drawer: hiding the doll restores the left-column arrows and closes a locked flyout", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    setWindow(NS, state, false)
    for _, slot in ipairs(LEFT_COLUMN) do
        local b = M.__slotButtons[slot]
        local p = b.popoutButton.pts
        assertEqual(#p, 1, slot)
        assertEqual(p[1][1], "LEFT", slot); assertEqual(p[1][2], b, slot); assertEqual(p[1][3], "RIGHT", slot)
        assertEqual(p[1][4], -8, slot); assertEqual(p[1][5], 0, slot)
    end
    local head = M.__slotButtons.HeadSlot.popoutButton
    -- red under: hiding a locked arrow without closing its flyout (EquipmentFlyout_Hide unlocks it).
    assertFalse(M.EquipmentFlyoutFrame:IsShown(), "a locked flyout outlived its hidden arrow")
    assertFalse(head.flyoutLocked == true, "the lock was left set")
    sameCoords(head:GetNormalTexture().coords, ARROW_FWD, "the closed flyout's arrow is Blizzard's unreversed one")
    sameCoords(M.__slotButtons.NeckSlot.popoutButton:GetNormalTexture().coords, ARROW_FWD, "a closed one, unreversed")
    assertEqual(#bf.pts, 1)
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][2], head); assertEqual(bf.pts[1][3], "TOPRIGHT")
    assertEqual(bf.pts[1][4], 0); assertEqual(bf.pts[1][5], -3)
end)

-- Forever smoke feedback S7 (owner, 2026-11-09): the drawer is the paper doll's, not the window's.
test("drawer: the doll shown with the window closed turns the drawer outward", function()
    local NS, M, state = drawerInstance()
    local total = 0
    for _ in pairs(M.__slotButtons) do total = total + 1 end
    state.doll = true
    QS(NS).DrawerSync()
    -- red under: the 2026-11-04 gate (the window on screen, NS.Dock.IsVisible).
    assertEqual(arrowsShown(M), total, "every arrow shows on the plain Character tab")
    if not FOREVER then
        assertEqual(M.__slotButtons.HeadSlot.popoutButton.pts[1][1], "RIGHT", "the left column's arrow is outward")
    end
    state.doll = false
    QS(NS).DrawerSync()
    assertEqual(arrowsShown(M), 0, "the arrows go with the doll")
end)

test("drawer: window.drawer off keeps Blizzard's drawer with the doll shown", function()
    local NS, M, state = drawerInstance()
    NS.db.profile.window.drawer = false
    state.doll = true
    QS(NS).DrawerSync()
    assertEqual(arrowsShown(M), 0)
    assertEqual(M.__slotButtons.HeadSlot.popoutButton.writes, 0)
end)

test("drawer: stood down nothing is moved", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    NS.ApplyEnabled(false)
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    M.EquipmentFlyoutPopoutButton_SetReversed(M.__slotButtons.HeadSlot.popoutButton, false)
    assertEqual(bf.writes, 1, "the stood-down drawer moved the flyout")
    for _, slot in ipairs(LEFT_COLUMN) do
        assertEqual(M.__slotButtons[slot].popoutButton.writes, 0, slot)
    end
    for slot, b in pairs(M.__slotButtons) do
        assertEqual(b.popoutButton.shows, 0, slot .. ": a stood-down drawer showed an arrow")
    end
    sameCoords(M.__slotButtons.HeadSlot.popoutButton:GetNormalTexture().coords, ARROW_FWD)
end)

test("drawer: a stand-down with the doll shown puts Blizzard's drawer back", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    openFlyout(M, "HeadSlot")
    -- red under: drop the drawer restore from QuickSlots.Suspend.
    NS.ApplyEnabled(false)
    local head = M.__slotButtons.HeadSlot.popoutButton
    assertEqual(head.pts[1][1], "LEFT")
    assertEqual(M.EquipmentFlyoutFrame.buttonFrame.pts[1][1], "TOPLEFT")
end)

test("drawer: in combat lockdown nothing is moved", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M, state = drawerInstance()
    M.__lockdown = true
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    assertEqual(bf.writes, 1, "the drawer moved the flyout in lockdown")
    assertEqual(M.__slotButtons.HeadSlot.popoutButton.writes, 0, "the drawer moved an arrow in lockdown")
    M.EquipmentFlyoutPopoutButton_HideAll()
    for slot, b in pairs(M.__slotButtons) do
        assertEqual(b.popoutButton.shows, 0, slot .. ": an arrow was shown in lockdown")
    end
end)

test("drawer: a HideAll after lockdown begins, with the drawer already out, shows no arrow", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local before = {}
    for slot, b in pairs(M.__slotButtons) do before[slot] = b.popoutButton.shows end
    M.__lockdown = true
    M.EquipmentFlyoutPopoutButton_HideAll()
    M.__lockdown = false
    -- red under: onHideAll without its locked() guard (the drawer is on, so only lockdown stops it)
    for slot, b in pairs(M.__slotButtons) do
        assertEqual(b.popoutButton.shows, before[slot], slot .. ": an arrow was re-shown in lockdown")
    end
end)

test("drawer: a missing Blizzard function installs nothing and errors nothing", function()
    local NS, M, state = drawerInstance({ drop = { "EquipmentFlyout_UpdateItems",
                                                   "EquipmentFlyoutPopoutButton_SetReversed",
                                                   "EquipmentFlyoutPopoutButton_HideAll" } })
    -- red under: an unguarded hooksecurefunc by name (the stand-in raises on a missing global).
    for _, h in ipairs(M.__hooks) do
        assertTrue(h.name ~= "EquipmentFlyout_UpdateItems" and h.name ~= "EquipmentFlyoutPopoutButton_SetReversed"
            and h.name ~= "EquipmentFlyoutPopoutButton_HideAll", "hooked a missing function")
    end
    setWindow(NS, state, true)
    setWindow(NS, state, false)
end)

-- ── the arrows (smoke round 2 design G3) ─────────────────────────────────────────────────────────

test("arrows: shown on every slot, weapons included, while the doll shows; hidden when it closes", function()
    local NS, M, state = drawerInstance()
    local total = 0
    for _ in pairs(M.__slotButtons) do total = total + 1 end
    assertEqual(arrowsShown(M), 0, "Blizzard's template is hidden")
    setWindow(NS, state, true)
    -- red under: no showArrows in DrawerSync (Blizzard shows them on the Equipment Manager pane only).
    assertEqual(arrowsShown(M), total)
    assertTrue(M.__slotButtons.MainHandSlot.popoutButton:IsShown(), "the weapons' arrow")
    setWindow(NS, state, false)
    assertEqual(arrowsShown(M), 0)
end)

test("arrows: shown once per change, not on every sync", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    QS(NS).DrawerSync()
    QS(NS).DrawerSync()
    assertEqual(M.__slotButtons.HeadSlot.popoutButton.shows, 1)
end)

test("arrows: hiding the doll leaves the Equipment Manager pane's arrows shown", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    M.PaperDollFrame.EquipmentManagerPane:Show()
    M.EquipmentFlyoutPopoutButton_ShowAll()
    local hides = M.__slotButtons.HeadSlot.popoutButton.hides
    setWindow(NS, state, false)
    -- red under: hide every arrow whatever the pane (the Equipment Manager would lose its own).
    assertEqual(M.__slotButtons.HeadSlot.popoutButton.hides, hides)
    assertTrue(arrowsShown(M) > 0)
end)

test("arrows: Blizzard's HideAll while the doll shows puts them back", function()
    local NS, M, state = drawerInstance()
    local total = 0
    for _ in pairs(M.__slotButtons) do total = total + 1 end
    setWindow(NS, state, true)
    M.EquipmentFlyoutPopoutButton_HideAll()       -- the Equipment Manager pane's OnHide
    -- red under: no HideAll post-hook (leaving the Equipment Manager tab would hide ours).
    assertEqual(arrowsShown(M), total)
end)

test("arrows: Blizzard's HideAll with the doll hidden leaves them hidden", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    setWindow(NS, state, false)
    M.EquipmentFlyoutPopoutButton_ShowAll()
    M.EquipmentFlyoutPopoutButton_HideAll()
    assertEqual(arrowsShown(M), 0)
end)

test("arrows: Blizzard's HideAll never reopens a flyout it closed", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    openFlyout(M, "HeadSlot")
    M.EquipmentFlyoutPopoutButton_HideAll()
    assertFalse(M.EquipmentFlyoutFrame:IsShown())
    assertTrue(M.__slotButtons.HeadSlot.popoutButton:IsShown(), "the arrow is back")
end)

test("arrows: a stand-down with the doll shown hides them", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    -- red under: a stand-down that leaves the arrows to the window.
    NS.ApplyEnabled(false)
    assertEqual(arrowsShown(M), 0)
end)

-- ── WoW Forever's outward drawer (ruling D4; Forever smoke feedback S7, S3) ────────────────────────
local function lastPoint(r) return r.pts[#r.pts] end
local function samePoint(p, want, msg)
    for i = 1, 5 do assertEqual(p[i], want[i], (msg or "") .. " [" .. i .. "]") end
end

test("drawer (Forever): the doll shown turns every arrow outward by F-UI's own anchor and rotation", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local head, hands, main = M.__slotButtons.HeadSlot, M.__slotButtons.HandsSlot, M.__slotButtons.MainHandSlot
    -- red under: the 2026-11-08 drawer that moved nothing on Forever (MOVES_DRAWER false).
    samePoint(lastPoint(head.popoutButton), { "RIGHT", head, "LEFT", -5, 0 }, "left column")
    samePoint(lastPoint(hands.popoutButton), { "LEFT", hands, "RIGHT", 5, 0 }, "right column")
    samePoint(lastPoint(main.popoutButton), { "TOP", main, "BOTTOM", 0, -5 }, "bottom row")
    assertEqual(head.popoutButton:GetNormalTexture().rotation, 0, "a LEFT arrow")
    assertEqual(hands.popoutButton:GetHighlightTexture().rotation, math.pi, "a RIGHT arrow")
    assertEqual(main.popoutButton:GetPushedTexture().rotation, math.pi, "a DOWN arrow")
    assertEqual(head.flyoutDirection, "RIGHT", "Blizzard's flyoutDirection is never written")
end)

test("drawer (Forever): a slot whose BorderFrame is hidden takes its arrow flush (S3)", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M, state = drawerInstance()
    local head = M.__slotButtons.HeadSlot
    head.BorderFrame.shown = false
    setWindow(NS, state, true)
    -- red under: F-UI's 5 px gap kept with the art that covers it hidden (Chonky's sheet).
    samePoint(lastPoint(head.popoutButton), { "RIGHT", head, "LEFT", 0, 0 })
end)

test("drawer (Forever): an open flyout opens outward by F-UI's formula for that direction", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local head = M.__slotButtons.HeadSlot
    local bf = openFlyout(M, "HeadSlot")
    samePoint(lastPoint(bf), { "TOPRIGHT", head.popoutButton, "TOPLEFT", 0, -3 }, "the left column opens left")
    local main = M.__slotButtons.MainHandSlot
    bf = openFlyout(M, "MainHandSlot")
    samePoint(lastPoint(bf), { "TOPLEFT", main.popoutButton, "BOTTOMLEFT", 0, 0 }, "the bottom row opens down")
    assertEqual(main.popoutButton:GetNormalTexture().rotation, math.pi, "the lock's repaint is turned back down")
end)

test("drawer (Forever): Blizzard's repaint on enter keeps the arrow outward", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local hands = M.__slotButtons.HandsSlot.popoutButton
    M.EquipmentFlyoutPopoutButton_RefreshVisualState(hands)
    -- red under: no RefreshVisualState post-hook (Blizzard turns it back inward on every state change).
    assertEqual(hands:GetNormalTexture().rotation, math.pi)
end)

test("drawer (Forever): the doll hidden puts Blizzard's arrows and flyout back", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local head = M.__slotButtons.HeadSlot
    local bf = openFlyout(M, "HeadSlot")
    head.popoutButton.flyoutLocked = false        -- an unlocked open (the slot's own click)
    state.doll = false
    QS(NS).DrawerSync()
    samePoint(lastPoint(head.popoutButton), { "LEFT", head, "RIGHT", 5, 0 }, "Blizzard's anchor")
    assertEqual(head.popoutButton:GetNormalTexture().rotation, math.pi, "Blizzard's own RIGHT turn")
    samePoint(lastPoint(bf), { "TOPLEFT", head.popoutButton, "TOPRIGHT", 0, -3 }, "Blizzard's flyout anchor")
end)

test("drawer (Forever): in combat lockdown nothing is moved or turned", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M, state = drawerInstance()
    M.__lockdown = true
    setWindow(NS, state, true)
    local head = M.__slotButtons.HeadSlot.popoutButton
    M.EquipmentFlyoutPopoutButton_RefreshVisualState(head)
    -- red under: DrawerSync or the RefreshVisualState post-hook without the lockdown guard.
    assertEqual(head.writes, 0, "an arrow was moved in lockdown")
    assertEqual(head:GetNormalTexture().rotation, math.pi, "Blizzard's own turn stands")
end)
