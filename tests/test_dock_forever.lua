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
