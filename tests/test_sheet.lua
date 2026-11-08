-- tests/test_sheet.lua — modules/Sheet.lua, NS.Sheet: which character sheet is up (stock, EllesmereUI,
-- ChonkyCharacterSheet) and where on it the outfit button and the window go (sheet and window
-- feedback design G1-G3, plan Task 3.1).
--
-- A sheet addon counts only when it is loaded AND its own frame is there: EllesmereUI with its
-- "blizzard" style never builds EUI_CharSheet_Equipment (built is enough: it hides the tab off the
-- Character tab), and Chonky skips its setup in combat or M+ (AreSecretsDisabled), leaving
-- CharacterFrameBgbg hidden (shown is needed). Both fall back to the stock anchors.
-- The sheets are the mock's (tests/wow_mock.lua `M.__sheets`): the stock sidebar tabs on every build,
-- the EllesmereUI tab and the Chonky backdrop and side panels only when a case asks for them.

local T = _G.OUTFITTERREBORN_TEST
-- OR-F5: the cases that pin Retail's placement skip on the forever kit profile.
local FOREVER = dofile("tests/_kit/mock_client.lua").current() == "forever"
local RETAIL_ONLY = "Retail's sheet button (sidebar tab, EllesmereUI, Chonky); WoW Forever's is the outer side-tab strip (ruling D8)"
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function fresh()
    local inst = T.load()
    return inst.NS, inst.mocks
end

-- Mark an addon loaded and let the adapter re-read it (the dock does this on every sheet show).
local function markLoaded(NS, M, name)
    M.__loadedAddOns[name] = true
    NS.Sheet.Refresh()
end

test("sheet: NS.Sheet is published with the adapter's surface", function()
    local S = T.NS.Sheet
    assertEqual(type(S), "table")
    for _, k in ipairs({ "Kind", "Frame", "ButtonAnchor", "TabIconOffset", "DockRight", "Refresh" }) do
        assertEqual(type(S[k]), "function", k)
    end
end)

test("sheet: stock by default", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = fresh()
    NS.Sheet.Refresh()
    assertEqual(NS.Sheet.Kind(), "stock")
    assertEqual(NS.Sheet.Frame(), M.CharacterFrame)
    -- Smoke round 2 design G2: a tab of the sidebar's own shape, its bottom on the neighbors' line.
    -- red under: the old LEFT/RIGHT square (33 x 33) with no look.
    local point, rel, relPoint, x, y, w, h, look = NS.Sheet.ButtonAnchor()
    assertEqual(point, "BOTTOMLEFT"); assertEqual(rel, M.PaperDollSidebarTab3); assertEqual(relPoint, "BOTTOMRIGHT")
    assertEqual(x, 4); assertEqual(y, 0)
    -- PaperDollSidebarTabTemplate is 33 x 35 (wow-ui-source@297d7aa PaperDollFrame.xml:393-394).
    assertEqual(w, 33); assertEqual(h, 35)
    assertEqual(look, "tab")
end)

test("sheet: without the stock tab the button keeps its place left of the close X, as a tab", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = fresh()
    M.PaperDollSidebarTab3 = nil
    NS.Sheet.Refresh()
    local point, rel, relPoint, x, y, w, h, look = NS.Sheet.ButtonAnchor()
    assertEqual(point, "RIGHT"); assertEqual(rel, M.CharacterFrameCloseButton); assertEqual(relPoint, "LEFT")
    assertEqual(x, -2); assertEqual(y, 0)
    assertEqual(w, 33); assertEqual(h, 35); assertEqual(look, "tab")
end)

-- Smoke round 3 E10: the outfit tab's icon centers where the neighbor tab's icon does. The template
-- anchors its 33 x 35 Icon BOTTOM 1,-2 on a 33 x 35 tab (wow-ui-source@297d7aa:Interface/AddOns/
-- Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393-394, :406-411): 1 right of, 2 below center.
test("sheet: the tab icon's offset is read from the neighbor tab's icon", function()
    local NS, M = fresh()
    NS.Sheet.Refresh()
    local dx, dy = NS.Sheet.TabIconOffset()
    assertEqual(dx, 1); assertEqual(dy, -2)
    -- Read live, not a constant: a neighbor icon placed elsewhere moves ours with it.
    -- red under: TabIconOffset answering the template's constants.
    local tab3 = M.PaperDollSidebarTab3
    tab3.Icon:ClearAllPoints()
    tab3.Icon:SetPoint("BOTTOM", tab3, "BOTTOM", 3, 0)
    tab3.Icon:SetSize(33, 31)
    dx, dy = NS.Sheet.TabIconOffset()
    assertEqual(dx, 3); assertEqual(dy, -2)
end)

test("sheet: the tab icon falls back to the template's offset when the neighbor's is unreadable", function()
    local NS, M = fresh()
    NS.Sheet.Refresh()
    local tab3 = M.PaperDollSidebarTab3
    -- Another anchor shape (a skin re-anchored it): its offsets mean something else.
    tab3.Icon:ClearAllPoints()
    tab3.Icon:SetPoint("CENTER", tab3, "CENTER", 7, 7)
    local dx, dy = NS.Sheet.TabIconOffset()
    assertEqual(dx, 1); assertEqual(dy, -2)
    -- Anchored to some other frame.
    tab3.Icon:ClearAllPoints()
    tab3.Icon:SetPoint("BOTTOM", M.CharacterFrame, "BOTTOM", 7, 7)
    dx, dy = NS.Sheet.TabIconOffset()
    assertEqual(dx, 1); assertEqual(dy, -2)
    -- No icon, then no tab.
    tab3.Icon = nil
    dx, dy = NS.Sheet.TabIconOffset()
    assertEqual(dx, 1); assertEqual(dy, -2)
    M.PaperDollSidebarTab3 = nil
    dx, dy = NS.Sheet.TabIconOffset()
    assertEqual(dx, 1); assertEqual(dy, -2)
end)

test("sheet: EllesmereUI with its equipment tab shown is eui", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = fresh()
    local tab = M.__sheets.eui()
    markLoaded(NS, M, "EllesmereUIBlizzardSkin")
    assertEqual(NS.Sheet.Kind(), "eui")
    assertEqual(NS.Sheet.Frame(), M.CharacterFrame)
    -- Smoke round 2 design G2: a 64 x 25 text label (EUI's own label size) stacked directly above
    -- the Equipment label and centered on it. red under: the old 20 px square right of the label.
    local point, rel, relPoint, x, y, w, h, look = NS.Sheet.ButtonAnchor()
    assertEqual(point, "BOTTOM"); assertEqual(rel, tab); assertEqual(relPoint, "TOP")
    assertEqual(x, 0); assertEqual(y, 0); assertEqual(w, 64); assertEqual(h, 25)
    assertEqual(look, "text")
end)

test("sheet: EllesmereUI loaded with the blizzard style resolves to stock", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = fresh()
    markLoaded(NS, M, "EllesmereUIBlizzardSkin")
    assertEqual(M.EUI_CharSheet_Equipment, nil)
    assertEqual(NS.Sheet.Kind(), "stock")
    assertEqual(NS.Sheet.Frame(), M.CharacterFrame)
    local _, rel = NS.Sheet.ButtonAnchor()
    assertEqual(rel, M.PaperDollSidebarTab3)
end)

test("sheet: EllesmereUI's tab hidden off the Character tab still reads eui", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = fresh()
    -- EllesmereUI hides its three text tabs on the Reputation and Currency tabs and shows them again
    -- from a PaperDollFrame OnShow hook (EllesmereUIBlizzardSkin_CharacterSheet.lua:1025-1090) that
    -- runs after the dock's, so a hidden tab is EllesmereUI's tab state, not a different sheet.
    -- red under: detect the EllesmereUI sheet by the tab being SHOWN (it read "stock" off the doll).
    local tab = M.__sheets.eui()
    tab:Hide()
    markLoaded(NS, M, "EllesmereUIBlizzardSkin")
    assertEqual(NS.Sheet.Kind(), "eui")
    local _, rel = NS.Sheet.ButtonAnchor()
    assertEqual(rel, tab)
end)

test("sheet: the EllesmereUI tab without the addon loaded is stock", function()
    local NS, M = fresh()
    M.__sheets.eui()
    NS.Sheet.Refresh()
    assertEqual(NS.Sheet.Kind(), "stock")
end)

test("sheet: Chonky with its backdrop shown is chonky", function()
    if FOREVER then T.skip(RETAIL_ONLY) end
    local NS, M = fresh()
    local bg = M.__sheets.chonky()
    markLoaded(NS, M, "ChonkyCharacterSheet")
    assertEqual(NS.Sheet.Kind(), "chonky")
    assertEqual(NS.Sheet.Frame(), bg)
    -- Chonky keeps Blizzard's sidebar tabs, so the button is the same tab as on the stock sheet.
    local point, rel, relPoint, x, y, w, h, look = NS.Sheet.ButtonAnchor()
    assertEqual(point, "BOTTOMLEFT"); assertEqual(rel, M.PaperDollSidebarTab3); assertEqual(relPoint, "BOTTOMRIGHT")
    assertEqual(x, 4); assertEqual(y, 0); assertEqual(w, 33); assertEqual(h, 35); assertEqual(look, "tab")
end)

test("sheet: Chonky skipped its setup (backdrop hidden) resolves to stock", function()
    local NS, M = fresh()
    M.__sheets.chonky():Hide()
    markLoaded(NS, M, "ChonkyCharacterSheet")
    assertEqual(NS.Sheet.Kind(), "stock")
    assertEqual(NS.Sheet.Frame(), M.CharacterFrame)
end)

test("sheet: the kind is re-read on Refresh, not fixed at the first answer", function()
    local NS, M = fresh()
    NS.Sheet.Refresh()
    assertEqual(NS.Sheet.Kind(), "stock")
    M.__sheets.eui()
    markLoaded(NS, M, "EllesmereUIBlizzardSkin")
    assertEqual(NS.Sheet.Kind(), "eui")
end)

test("sheet: DockRight is the sheet's right edge and top", function()
    local NS, M = fresh()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    NS.Sheet.Refresh()
    local x, top = NS.Sheet.DockRight()
    assertEqual(x, 300); assertEqual(top, 500)
end)

test("sheet: DockRight answers nil while the sheet has never been laid out", function()
    local NS = fresh()
    NS.Sheet.Refresh()
    local x, top = NS.Sheet.DockRight()
    assertEqual(x, nil); assertEqual(top, nil)
end)

test("sheet: DockRight takes the rightmost shown Chonky side panel", function()
    local NS, M = fresh()
    local bg = M.__sheets.chonky()
    M.__sheets.place(bg, 400, 520)
    -- Chonky's side panels (core/tables.lua:80-86, Retail/characterSheet.lua:1762-1771): CCSf and the
    -- M+, raid and GearFinder `_sf` frames, each hanging off its zero-width `_af` anchor.
    local mplus = M.__sheets.chonkyPanel("ccsm_sf", 700, 520)
    M.__sheets.chonkyPanel("ccsrf_sf", 900, 520):Hide()
    M.__sheets.chonkyPanel("ccsgf_sf", 650, 520)
    markLoaded(NS, M, "ChonkyCharacterSheet")
    local x, top = NS.Sheet.DockRight()
    assertEqual(x, 700, "the shown M+ panel, not the hidden raid one")
    assertEqual(top, 520)
    mplus:Hide()
    x = NS.Sheet.DockRight()
    assertEqual(x, 650)
end)

test("sheet: a scaled Chonky panel's edge is read in the sheet's units", function()
    local NS, M = fresh()
    local bg = M.__sheets.chonky()
    M.__sheets.place(bg, 400, 520)
    -- ccsm_sf takes its own scale (mplus_sp_scale, Retail/mythicPlusStats.lua:1064).
    local panel = M.__sheets.chonkyPanel("ccsm_sf", 1000, 600)
    rawset(panel, "GetEffectiveScale", function() return 0.5 end)
    markLoaded(NS, M, "ChonkyCharacterSheet")
    local x = NS.Sheet.DockRight()
    assertEqual(x, 500)
end)

test("sheet: with no Chonky panel shown DockRight is the backdrop's edge", function()
    local NS, M = fresh()
    local bg = M.__sheets.chonky()
    M.__sheets.place(bg, 400, 520)
    M.__sheets.chonkyPanel("CCSf", 900, 520):Hide()
    markLoaded(NS, M, "ChonkyCharacterSheet")
    local x, top = NS.Sheet.DockRight()
    assertEqual(x, 400); assertEqual(top, 520)
end)

test("sheet: the adapter creates, anchors and shows nothing", function()
    local NS, M = fresh()
    local before = #M.__shownFrames()
    M.__sheets.eui()
    markLoaded(NS, M, "EllesmereUIBlizzardSkin")
    local after = #M.__shownFrames()
    NS.Sheet.Kind(); NS.Sheet.Frame(); NS.Sheet.ButtonAnchor(); NS.Sheet.DockRight()
    assertTrue(#M.__shownFrames() == after, "no frame shown by the reads")
    assertTrue(after == before + 1, "only the mock's own tab")
end)

-- ── WoW Forever's outer side-tab strip (ruling D8, OR-F5) ────────────────────────────────────────
-- The mock's strip (tests/wow_mock.lua): CharacterFrameModeTab1..6, shown, 55 x 60, 6 px apart.

local FOREVER_ONLY = "pins WoW Forever's sheet button (ruling D8); runs on the forever kit profile"

test("sheet (Forever): the button is one more tab below the last mode tab, at the strip's spacing", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = fresh()
    NS.Sheet.Refresh()
    -- red under: Retail's anchor on Forever (right of PaperDollSidebarTab3, which is Titles there).
    local point, rel, relPoint, x, y, w, h, look = NS.Sheet.ButtonAnchor()
    assertEqual(point, "TOPLEFT"); assertEqual(rel, M.CharacterFrameModeTab6); assertEqual(relPoint, "BOTTOMLEFT")
    assertEqual(x, 0); assertEqual(y, -6)
    assertEqual(w, 55); assertEqual(h, 60)
    assertEqual(look, "sidetab")
end)

test("sheet (Forever): a hidden last tab gives the place to the last shown one", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = fresh()
    M.CharacterFrameModeTab6:Hide()
    local _, rel, _, _, y = NS.Sheet.ButtonAnchor()
    -- red under: anchoring to Tab6 by name, shown or not.
    assertEqual(rel, M.CharacterFrameModeTab5); assertEqual(y, -6)
end)

test("sheet (Forever): unlaid tabs take the fallback gap, and no tab at all the close X's place", function()
    if not FOREVER then T.skip(FOREVER_ONLY) end
    local NS, M = fresh()
    rawset(M.CharacterFrameModeTab5, "GetBottom", function() return nil end)
    local _, rel, _, _, y = NS.Sheet.ButtonAnchor()
    assertEqual(rel, M.CharacterFrameModeTab6); assertEqual(y, -4)
    for i = 1, 6 do M["CharacterFrameModeTab" .. i]:Hide() end
    local point, rel2, relPoint, x, y2, w, h, look = NS.Sheet.ButtonAnchor()
    assertEqual(point, "RIGHT"); assertEqual(rel2, M.CharacterFrameCloseButton); assertEqual(relPoint, "LEFT")
    assertEqual(x, -2); assertEqual(y2, 0); assertEqual(w, 55); assertEqual(h, 55); assertEqual(look, "sidetab")
end)
