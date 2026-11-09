-- tests/test_dock_forever.lua — modules/Dock.lua's sheet button on WoW Forever (ruling D8, OR-F5):
-- one more tab of the outer side-tab strip, made from LargeSideTabButtonTemplate when the client has
-- it. Split from tests/test_dock.lua (the file budget). Every case runs on the forever kit profile only.

local T = _G.OUTFITTERREBORN_TEST
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local FOREVER_ONLY = "pins WoW Forever's sheet button (ruling D8); runs on the forever kit profile"
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local scene = dofile(T.root .. "/tests/dock_scene.lua")(T)

-- The last SetPoint the sheet button was given.
local function buttonPoint(M)
    local pts = M.OutfitterRebornSheetButton.__pts
    return pts[#pts]
end

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

test("dock (Forever): the template's unsized Icon takes the outfit icon, filled as the mode tabs fill theirs", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local filled
    local _, M = scene({ mutate = function(M)
        M.C_XMLUtil = { GetTemplateInfo = function(name)
            if name == "LargeSideTabButtonTemplate" then return { type = "Frame" } end
        end }
        -- The template's own regions (SharedUIPanelTemplates.xml:1008): an Icon with no size, and
        -- SidePanelTabButtonMixin's SetFillToInterior.
        local create = M.CreateFrame
        M.CreateFrame = function(kind, name, parent, template, ...)
            local f = create(kind, name, parent, template, ...)
            if template == "LargeSideTabButtonTemplate" then
                rawset(f, "Icon", f:CreateTexture(nil, "ARTWORK"))
                rawset(f, "SetFillToInterior", function(_, on) filled = on end)
            end
            return f
        end
    end })
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    assertEqual(button.Icon:GetTexture(), 132724, "the template's Icon wears the outfit icon")
    -- red under: SetTexture alone on the template's unsized Icon (it draws nothing in the client).
    assertTrue(filled, "the Icon was sized through SetFillToInterior")
    assertFalse(button.icon:IsShown(), "the button's own icon stays hidden behind the template's")
end)

-- ── Forever smoke feedback S4 and S1 ─────────────────────────────────────────────────────────────
test("dock (Forever): the button stays on the other tabs and goes with CharacterFrame (S4)", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = scene()
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    M.PaperDollFrame:Hide(); M.PaperDollFrame:__fire("OnHide")       -- the Reputation tab
    -- red under: Retail's rule on Forever (the doll's OnHide hides the button).
    assertTrue(button:IsShown(), "the button left with the paper doll")
    M.__world:closeCharacter()
    assertFalse(button:IsShown(), "CharacterFrame's hide keeps the button up")
end)

test("dock (Forever): the button takes the strip's scale (S1)", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local scale
    local _, M = scene({ mutate = function(M)
        local create = M.CreateFrame
        M.CreateFrame = function(kind, name, ...)
            local f = create(kind, name, ...)
            if name == "OutfitterRebornSheetButton" then rawset(f, "SetScale", function(_, v) scale = v end) end
            return f
        end
    end })
    rawset(M.CharacterFrameModeTab6, "GetEffectiveScale", function() return 0.8 end)
    rawset(M.CharacterFrame, "GetEffectiveScale", function() return 1 end)
    M.__world:openCharacter()
    -- red under: placeButton without SetScale.
    assertEqual(scale, 0.8)
end)

test("dock (Forever): on Chonky's skinned strip the button wears its skin, not the template's (S1)", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = scene()
    rawset(M.CharacterFrameModeTab6, "CCS_BG", {
        IsShown = function() return true end, GetTexture = function() return "ccs-tab.tga" end,
        GetTexCoord = function() return 0, 0, 0, 1, 1, 0, 1, 1 end,
        GetVertexColor = function() return 0.3, 0.4, 0.5, 1 end,
    })
    M.__world:openCharacter()
    local button = M.OutfitterRebornSheetButton
    assertTrue(button.ccsBg ~= nil and button.ccsBg:IsShown(), "Chonky's fill")
    assertEqual(button.ccsBg:GetTexture(), "ccs-tab.tga", "the neighbor's file")
    assertTrue(button.ccsIcon:IsShown(), "the round icon")
    assertFalse(button.icon:IsShown(), "the plain icon is hidden")
    assertFalse(button.ccsGlow:IsShown(), "no glow with the window closed")
end)

-- ── Forever smoke feedback S5: the window widens under a side strip ────────────────────────────────
test("dock (Forever): a strip down the sheet's edge widens the window and moves its contents right (S5)", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = scene()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    for i = 1, 6 do
        rawset(M["CharacterFrameModeTab" .. i], "GetLeft", function() return 298 end)
        rawset(M["CharacterFrameModeTab" .. i], "GetRight", function() return 353 end)
    end
    M.__world:openCharacter()
    NS.Dock.Open()
    local win = M.OutfitterRebornWindow
    local p = win.__pts[#win.__pts]
    -- red under: moving the window clear of the strip instead of widening it (the owner's ruling).
    assertEqual(p[4], 300, "the window keeps its dock point")
    local inset = 353 - 300
    assertEqual(NS.Window.Size(), NS.Window.WIDTH + inset - 8, "the window is wider by the strip's reach, less its own padding")
    local list = M.OutfitterRebornWindowList
    local lp = list.__pts[#list.__pts]
    -- red under: the 2026-11-09 band (4 px margin plus the list's 8 px padding past the tabs, R2-2).
    assertEqual(lp[4], inset, "the rows start flush with the strip's edge")
    local new = M.OutfitterRebornNewOutfitButton
    assertEqual(new.__pts[#new.__pts][4], inset, "so does the footer")
    -- The strip moves clear (a Chonky side panel opens): the follow narrows the window again.
    for i = 1, 6 do
        rawset(M["CharacterFrameModeTab" .. i], "GetLeft", function() return 900 end)
        rawset(M["CharacterFrameModeTab" .. i], "GetRight", function() return 955 end)
    end
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 0.05)
    assertEqual(NS.Window.Size(), NS.Window.WIDTH)
    assertEqual(list.__pts[#list.__pts][4], 8)
end)

-- ── Forever smoke feedback 2 ─────────────────────────────────────────────────────────────────────
test("dock (Forever): a strip re-laid while the sheet is open places the button again (R2-1)", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local _, M = scene({ mutate = function(M)
        -- The strip's SetPoint, made hookable (tests/mock_world.lua hooks only modeled tables).
        for _, f in ipairs({ M.CharacterFrame.ModeTabs, M.CharacterFrameModeTab2, M.CharacterFrameModeTab6 }) do
            rawset(f, "SetPoint", function() end)
            M.__hookable[f] = true
        end
    end })
    M.__world:openCharacter()
    M.__fireTimers()
    local button = M.OutfitterRebornSheetButton
    local before = #button.__pts
    -- Chonky's "Skin Character Tabs" turned off: its revert moves the strip and the tabs.
    M.CharacterFrame.ModeTabs:SetPoint("TOPLEFT", M.CharacterFrame, "TOPRIGHT", 2, -2)
    M.CharacterFrameModeTab2:SetPoint("TOPLEFT", M.CharacterFrameModeTab1, "BOTTOMLEFT", 0, -4)
    M.__fireTimers()
    -- red under: no SetPoint post-hook on the strip (the button kept the old row's place and skin).
    assertEqual(#button.__pts, before + 1, "placed again once, on the next frame")
end)

-- The owner's report, 2026-11-09: a tainted CharacterFrame show raises on Forever's secret health.
test("dock (Forever): Open with the character sheet closed keeps the wish and says so, never opening it", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = scene()
    M.__world:closeCharacter()
    local toggles = 0
    M.ToggleCharacter = function() toggles = toggles + 1 end
    M.__resetPrinted()
    assertFalse(NS.Dock.Open())
    -- red under: ToggleCharacter from addon code (CharacterFrame's OnShow then raises on secret health).
    assertEqual(toggles, 0)
    assertTrue(NS.Dock.wanted, "the wish is kept")
    assertTrue(table.concat(M.__printed(), "\n"):find("Open the character sheet", 1, true) ~= nil)
    M.ToggleCharacter = nil
    M.__world:openCharacter()
    assertTrue(NS.Dock.IsShown(), "the sheet's next show brings the window")
end)
