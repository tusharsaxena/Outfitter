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
    for _, k in ipairs({ "Kind", "Frame", "ButtonAnchor", "DockRight", "Refresh" }) do
        assertEqual(type(S[k]), "function", k)
    end
end)

test("sheet: stock by default", function()
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
    local NS, M = fresh()
    M.PaperDollSidebarTab3 = nil
    NS.Sheet.Refresh()
    local point, rel, relPoint, x, y, w, h, look = NS.Sheet.ButtonAnchor()
    assertEqual(point, "RIGHT"); assertEqual(rel, M.CharacterFrameCloseButton); assertEqual(relPoint, "LEFT")
    assertEqual(x, -2); assertEqual(y, 0)
    assertEqual(w, 33); assertEqual(h, 35); assertEqual(look, "tab")
end)

test("sheet: EllesmereUI with its equipment tab shown is eui", function()
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
    local NS, M = fresh()
    markLoaded(NS, M, "EllesmereUIBlizzardSkin")
    assertEqual(M.EUI_CharSheet_Equipment, nil)
    assertEqual(NS.Sheet.Kind(), "stock")
    assertEqual(NS.Sheet.Frame(), M.CharacterFrame)
    local _, rel = NS.Sheet.ButtonAnchor()
    assertEqual(rel, M.PaperDollSidebarTab3)
end)

test("sheet: EllesmereUI's tab hidden off the Character tab still reads eui", function()
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
