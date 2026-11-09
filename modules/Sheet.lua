local _, NS = ...
-- modules/Sheet.lua — NS.Sheet: which character sheet is up and where on it the outfit button and the
-- window go (sheet and window feedback design G1-G3). Three sheets: the stock one, EllesmereUI's
-- skinned sheet and ChonkyCharacterSheet. READS ONLY: it creates, anchors, shows and hides nothing;
-- modules/Dock.lua asks it on every sheet show and from the follow. On WoW Forever the button anchors
-- to the outer side-tab strip instead (ruling D8, foreverButtonAnchor), which Chonky may scale, lay
-- across and reskin (Forever smoke feedback S1); a strip down the sheet's right edge also widens the
-- window (S5, Sheet.StripInset). CCS-F is ChonkyCharacterSheet 2.5.04 as the owner's Forever client
-- has it.
--
-- DETECTION. A sheet addon counts only when it is loaded AND the frame it builds is there, so a sheet
-- addon whose skin is off falls back to the stock anchors instead of anchoring to a frame that was
-- never built:
--   eui     EllesmereUIBlizzardSkin loaded and EUI_CharSheet_Equipment built. It builds its tabs only
--           for its own Character Sheet style (EllesmereUIBlizzardSkin_CharacterSheet.lua:3121,
--           :3171), never for "blizzard", and the style is latched for the session (:13-33). BUILT,
--           NOT SHOWN: it hides the tabs off the Character tab (:1044-1047) and shows them again from
--           a PaperDollFrame OnShow hook installed at the first sheet open (:1079-1090, :4907), so
--           after the dock's hook. Read by visibility, the Reputation and Currency tabs and the
--           dock's own sheet show all read "stock".
--   chonky  ChonkyCharacterSheet loaded and CharacterFrameBgbg shown. During combat or M+
--           (AreSecretsDisabled) it defers its setup (core/events.lua:414-425), so the backdrop that
--           CCS.CreateChonkyCharacterBG builds (core/styles.lua:1072-1107) may not be up. Once up it
--           is CharacterFrame's child (:1090-1099) and stays up on every tab.
--   stock   everything else.
-- Whether an addon is loaded is read through NS.Compat and kept until the next Refresh (the dock
-- calls it on every sheet show), so the 0.05 s follow does not ask the client each tick. The frames
-- are read live.
--
-- CHONKY'S SIDE PANELS. CCSf and the M+, raid and GearFinder panels (ccsm_sf, ccsrf_sf, ccsgf_sf)
-- open to the right of the sheet. Each hangs TOPLEFT off a zero-width anchor frame (ccsf_af, ccsm_af,
-- ccsrf_af, ccsgf_af) that is always shown, so it is the panel, not its anchor, whose visibility and
-- right edge count (core/tables.lua:80-86, Retail/characterSheet.lua:1762-1771,
-- Retail/mythicPlusStats.lua:1047-1064). A panel carries its own scale (mplus_sp_scale), so its edge
-- is converted into the sheet frame's units.
--
-- CALLS (at call time): NS.Compat.IsAddOnLoaded, NS.SafeNumber. At load: NS.PerClient (core/ClientSetup.lua).

local Sheet = {}
NS.Sheet = Sheet

-- The stock sheet's Equipment Manager tab: PaperDollSidebarTabTemplate is 33 x 35, and Tab3 sits at
-- PaperDollSidebarTabs BOTTOMRIGHT -30,0 (wow-ui-source@297d7aa:Interface/AddOns/
-- Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393-394, :475-503).
local STOCK_TAB = "PaperDollSidebarTab3"
local TAB_W, TAB_H = 33, 35
local STOCK_GAP = 4
-- EllesmereUI's Equipment text tab, the last of its three (Character / Titles / Equipment): a 64 x 25
-- frame, its text TOP-anchored (EllesmereUIBlizzardSkin_CharacterSheet.lua:3123-3124, :3176-3183).
local EUI_TAB = "EUI_CharSheet_Equipment"
local EUI_LABEL_W, EUI_LABEL_H = 64, 25
local CHONKY_BACKDROP = "CharacterFrameBgbg"
Sheet.CHONKY_PANELS = { "CCSf", "ccsm_sf", "ccsrf_sf", "ccsgf_sf" }

local loaded -- { eui = bool, chonky = bool }, from the last Refresh

--- Re-read which sheet addons are loaded. The dock calls this on every sheet show.
function Sheet.Refresh()
    loaded = {
        eui = NS.Compat.IsAddOnLoaded("EllesmereUIBlizzardSkin"),
        chonky = NS.Compat.IsAddOnLoaded("ChonkyCharacterSheet"),
    }
end

-- A named frame that exists, else nil.
local function builtFrame(name)
    local f = _G[name]
    if type(f) ~= "table" or type(f.IsShown) ~= "function" then return nil end
    return f
end

-- A named frame that exists and is shown, else nil.
local function shownFrame(name)
    local f = builtFrame(name)
    if not f or f:IsShown() ~= true then return nil end
    return f
end

--- @return string "stock" | "eui" | "chonky"
function Sheet.Kind()
    if not loaded then Sheet.Refresh() end
    if loaded.eui and builtFrame(EUI_TAB) then return "eui" end
    if loaded.chonky and shownFrame(CHONKY_BACKDROP) then return "chonky" end
    return "stock"
end

--- @return table the visible sheet: CharacterFrame for stock and EllesmereUI, Chonky's backdrop for Chonky
function Sheet.Frame()
    if Sheet.Kind() == "chonky" then return _G[CHONKY_BACKDROP] end
    return CharacterFrame
end

local function scaleOf(f)
    local s = NS.SafeNumber(f:GetEffectiveScale(), 1)
    if s <= 0 then return 1 end
    return s
end

-- PaperDollSidebarTab3's size; the template's when it reads nothing.
local function stockTabSize(tab)
    local w, h = tab:GetSize()
    w, h = NS.SafeNumber(w, 0), NS.SafeNumber(h, 0)
    if w <= 0 or h <= 0 then return TAB_W, TAB_H end
    return w, h
end

-- WoW Forever's outer side-tab strip (ruling D8): CharacterFrame.ModeTabs holds CharacterFrameModeTab1..6
-- (Character, Reputation, Skills, PvP, Currency, Statistics), a vertical strip outside the frame's
-- right edge, drawn with LargeSideTabButtonTemplate (F-UI Camelot/CharacterFrame.xml:574-599,
-- Camelot/CharacterFrame.lua:154). It shows with the inner right pane expanded or collapsed, so one
-- placement covers both. Tab6 is 55 px wide and the strip 384 tall (probe P27); the height and the
-- spacing are read live from the tabs, these are the fallbacks.
local MODE_TAB = "CharacterFrameModeTab"
local MODE_TAB_COUNT = 6
local MODE_TAB_W, MODE_TAB_H = 55, 55 -- PROBE P27: the height is a guess; the width is the probe's
local MODE_TAB_GAP = 4                -- PROBE P27: used only when two shown tabs give no spacing

-- A frame's top or bottom, plain, or nil.
local function plainEdge(f, method)
    if type(f[method]) ~= "function" then return nil end
    return NS.SafeNumber(f[method](f), nil)
end

-- The shown mode tabs, in the strip's order.
local function shownModeTabs()
    local out = {}
    for i = 1, MODE_TAB_COUNT do out[#out + 1] = shownFrame(MODE_TAB .. i) end
    return out
end

-- The strip's spacing: the gap between the last two shown tabs along the strip, when both are laid
-- out (vertical: prev's bottom to last's top; horizontal: prev's right to last's left).
local function modeTabGap(prev, last, across)
    local a = prev and plainEdge(prev, across and "GetRight" or "GetBottom")
    local b = plainEdge(last, across and "GetLeft" or "GetTop")
    if not a or not b then return MODE_TAB_GAP end
    local gap = across and (b - a) or (a - b)
    if gap < 0 then return MODE_TAB_GAP end
    return gap
end

--- Whether the strip runs across, not down (Forever smoke feedback S1): ChonkyCharacterSheet's
--- "Skin Character Tabs" lays the mode tabs in a row under the sheet, each LEFT of the one before's
--- RIGHT (CCS-F core/styles.lua:1053-1064, Modules/Forever.lua:1225-1238). Read from the first two
--- shown tabs: level tops and the second starting at or past the first's right. Down when unread.
--- @return boolean
function Sheet.StripAcross(tabs)
    tabs = tabs or shownModeTabs()
    local a, b = tabs[1], tabs[2]
    if not (a and b) then return false end
    local at, bt = plainEdge(a, "GetTop"), plainEdge(b, "GetTop")
    local ar, bl = plainEdge(a, "GetRight"), plainEdge(b, "GetLeft")
    if not (at and bt and ar and bl) then return false end
    return math.abs(at - bt) < 1 and bl >= ar - 1
end

-- ChonkyCharacterSheet's own skin on a mode tab: its CCS_BG texture, shown (CCS-F core/styles.lua:875-883).
local function chonkySkinned(tab)
    local bg = rawget(tab, "CCS_BG")
    return type(bg) == "table" and type(bg.IsShown) == "function" and bg:IsShown() == true
end

-- The strip's scale in CharacterFrame's units (Forever smoke feedback S1): Chonky scales the strip to
-- 0.8 (CCS-F Modules/Forever.lua:1222), and the button, CharacterFrame's child, takes it so it is a
-- tab's size and its offsets read in the tabs' own units.
local function stripScale(tab)
    return scaleOf(tab) / scaleOf(CharacterFrame)
end

-- Forever: one more button of the outer strip, after the last shown mode tab, at its size, scale and
-- the strip's spacing: below it on a strip that runs down, right of it on one that runs across.
-- Outfitter's own frame (modules/Dock.lua): it never joins the strip's mode switching. On a strip in
-- Chonky's skin it wears a copy of that skin ("chonkytab"), else the strip's own template ("sidetab").
-- With no mode tab shown the button keeps the close X's place.
local function foreverButtonAnchor()
    local tabs = shownModeTabs()
    local last = tabs[#tabs]
    if not last then return "RIGHT", CharacterFrameCloseButton, "LEFT", -2, 0, MODE_TAB_W, MODE_TAB_H, "sidetab", 1 end
    local w, h = last:GetSize()
    w, h = NS.SafeNumber(w, 0), NS.SafeNumber(h, 0)
    if w <= 0 or h <= 0 then w, h = MODE_TAB_W, MODE_TAB_H end
    local look = chonkySkinned(last) and "chonkytab" or "sidetab"
    local scale = stripScale(last)
    if Sheet.StripAcross(tabs) then
        return "LEFT", last, "RIGHT", modeTabGap(tabs[#tabs - 1], last, true), 0, w, h, look, scale
    end
    return "TOPLEFT", last, "BOTTOMLEFT", 0, -modeTabGap(tabs[#tabs - 1], last, false), w, h, look, scale
end

--- Chonky's tab art, read off the last shown mode tab in its skin: the CCS_BG file and its eight
--- coords. nil when no shown tab wears it.
--- @return any|nil texture, table|nil coords
function Sheet.ChonkyTabArt()
    local tabs = shownModeTabs()
    local last = tabs[#tabs]
    if not (last and chonkySkinned(last)) then return nil end
    local bg = rawget(last, "CCS_BG")
    local tex = type(bg.GetTexture) == "function" and bg:GetTexture() or nil
    local coords = type(bg.GetTexCoord) == "function" and { bg:GetTexCoord() } or nil
    return tex, coords
end

-- A mode tab's CCS_BG color, or nil.
local function tabColor(tab)
    local bg = tab and rawget(tab, "CCS_BG")
    if type(bg) ~= "table" or type(bg.GetVertexColor) ~= "function" then return nil end
    local r, g, b, a = bg:GetVertexColor()
    r, g, b = NS.SafeNumber(r, nil), NS.SafeNumber(g, nil), NS.SafeNumber(b, nil)
    if not (r and g and b) then return nil end
    return { r, g, b, NS.SafeNumber(a, 1) }
end

local CHONKY_IDLE, CHONKY_ACTIVE = { 0.5, 0.5, 0.5, 1 }, { 1, 1, 1, 1 }

--- Chonky's tab colors, copied live (its color table is private): the selected mode tab's for the
--- active state, an unselected one's for idle (CCS-F core/styles.lua:931-947). Its fallbacks when
--- none answers.
--- @return table idle {r, g, b, a}, table active {r, g, b, a}
function Sheet.ChonkyTabColors()
    local getSelected = _G.PanelTemplates_GetSelectedTab
    local selected = type(getSelected) == "function"
        and NS.SafeNumber(getSelected(CharacterFrame), nil) or nil
    local idle, active
    for i, tab in ipairs(shownModeTabs()) do
        local id = type(tab.GetID) == "function" and NS.SafeNumber(tab:GetID(), i) or i
        if id == selected then
            active = active or tabColor(tab)
        else
            idle = idle or tabColor(tab)
        end
    end
    return idle or CHONKY_IDLE, active or CHONKY_ACTIVE
end

--- Where the outfit button goes and which host look it wears (smoke round 2 design G2): a sidebar
--- tab right of the Equipment Manager tab, bottoms on one line, on the stock and Chonky sheets
--- (Chonky keeps Blizzard's sidebar tabs); a text label stacked directly above the Equipment label,
--- centered on it, on EllesmereUI. Without the stock tab (another addon removed it) the tab keeps
--- the button's old place, left of the close X.
--- On WoW Forever (ruling D8) the button is one more tab of the outer side-tab strip instead, below
--- the last shown mode tab, in the strip's own look ("sidetab").
--- On Forever the strip may run across instead (Chonky), and the button takes the strip's scale.
--- @return string point, table relFrame, string relPoint, number x, number y, number w, number h,
---         string look  "tab" | "text" | "sidetab" | "chonkytab", number scale  in CharacterFrame's units
local function retailButtonAnchor()
    if Sheet.Kind() == "eui" then
        return "BOTTOM", _G[EUI_TAB], "TOP", 0, 0, EUI_LABEL_W, EUI_LABEL_H, "text", 1
    end
    local tab = _G[STOCK_TAB]
    if type(tab) == "table" then
        local w, h = stockTabSize(tab)
        return "BOTTOMLEFT", tab, "BOTTOMRIGHT", STOCK_GAP, 0, w, h, "tab", 1
    end
    return "RIGHT", CharacterFrameCloseButton, "LEFT", -2, 0, TAB_W, TAB_H, "tab", 1
end
Sheet.ButtonAnchor = NS.PerClient({ retail = retailButtonAnchor, forever = foreverButtonAnchor })

-- The template's Icon: 33 x 35, BOTTOM 1,-2 on the 33 x 35 tab, so its center sits 1 right of and 2
-- below the tab's (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/
-- PaperDollFrame.xml:406-411).
local TAB_ICON_DX, TAB_ICON_DY = 1, -2

--- Where the neighbor tab's icon centers, as an offset from the tab's center (smoke round 3 E10): read
--- live from PaperDollSidebarTab3.Icon, anchored BOTTOM to its tab's BOTTOM as the template lays it;
--- the template's own offset when there is no such icon or it is anchored some other way.
--- @return number dx, number dy
function Sheet.TabIconOffset()
    local tab = builtFrame(STOCK_TAB)
    local icon = tab and tab.Icon
    if type(icon) ~= "table" or type(icon.GetPoint) ~= "function" then return TAB_ICON_DX, TAB_ICON_DY end
    local point, rel, relPoint, x, y = icon:GetPoint(1)
    if point ~= "BOTTOM" or rel ~= tab or relPoint ~= "BOTTOM" then return TAB_ICON_DX, TAB_ICON_DY end
    local _, h = icon:GetSize()
    local _, tabH = stockTabSize(tab)
    return NS.SafeNumber(x, TAB_ICON_DX), NS.SafeNumber(y, 0) + (NS.SafeNumber(h, TAB_H) - tabH) / 2
end

-- EllesmereUI's own fallback for a missing accent (_paintTopButton, EllesmereUIBlizzardSkin_
-- CharacterSheet.lua:3136).
local EUI_ACCENT_FALLBACK = { r = 0.51, g = 0.784, b = 1 }

--- EllesmereUI's accent, read now: EllesmereUI updates ELLESMERE_GREEN in place when the player
--- changes it (EllesmereUI.lua:4419), so a paint-time read is always the live one.
--- @return number r, number g, number b
function Sheet.EUIAccent()
    local eui = EllesmereUI
    local c = type(eui) == "table" and type(eui.ELLESMERE_GREEN) == "table" and eui.ELLESMERE_GREEN
    if not c then c = EUI_ACCENT_FALLBACK end
    return NS.SafeNumber(c.r, EUI_ACCENT_FALLBACK.r), NS.SafeNumber(c.g, EUI_ACCENT_FALLBACK.g),
        NS.SafeNumber(c.b, EUI_ACCENT_FALLBACK.b)
end

--- EllesmereUI's Equipment label's font string (its `_text`), or nil: the face the label copies.
--- @return table|nil
function Sheet.EUILabelText()
    local tab = builtFrame(EUI_TAB)
    local text = tab and rawget(tab, "_text")
    if type(text) ~= "table" or type(text.GetFont) ~= "function" then return nil end
    return text
end

-- Chonky's backdrop draws its visible border its `insets` inside the frame's edge (CCS-F
-- Modules/Forever.lua:1277-1281: edgeSize 16, insets 3), so a window flush with the frame's top sits
-- above the line the eye reads as the top (Forever smoke feedback S2; measured in the owner's 6.png).
local CHONKY_TOP_INSET = 3

-- The Chonky backdrop's top inset, read off BackdropTemplateMixin's backdropInfo, else its value.
local function chonkyTopInset(frame)
    local info = rawget(frame, "backdropInfo")
    local insets = type(info) == "table" and info.insets
    local top = type(insets) == "table" and NS.SafeNumber(insets.top, nil)
    if not top or top < 0 then return CHONKY_TOP_INSET end
    return top
end

--- Where the window docks: the right edge of the sheet, or of the rightmost shown Chonky side panel,
--- and the sheet's top, both in the sheet frame's (Sheet.Frame()'s) units. nil, nil while the sheet
--- has never been laid out. On Chonky the top is its border's visible line (S2), not the frame's.
--- @return number|nil x, number|nil top
function Sheet.DockRight()
    local frame = Sheet.Frame()
    local right = NS.SafeNumber(frame:GetRight(), nil)
    local top = NS.SafeNumber(frame:GetTop(), nil)
    if not right or not top then return nil, nil end
    if not loaded.chonky then return right, top end
    if Sheet.Kind() == "chonky" then top = top - chonkyTopInset(frame) end
    local sheetScale = scaleOf(frame)
    for _, name in ipairs(Sheet.CHONKY_PANELS) do
        local panel = shownFrame(name)
        local edge = panel and NS.SafeNumber(panel:GetRight(), nil)
        if edge then
            edge = edge * scaleOf(panel) / sheetScale
            if edge > right then right = edge end
        end
    end
    return right, top
end

-- A strip that starts at most this far right of the window's left edge, and ends past it, hangs over
-- the window; one that ends before it stands clear (a Chonky side panel opens 63 px right of the
-- sheet to make room for the strip, CCS-F Modules/Forever.lua:1409, and the window docks past it).
local STRIP_SLACK = 12
-- The empty band's spare width past the strip's right edge.
local STRIP_MARGIN = 4

--- How far a side-tab strip down the sheet's right edge reaches over a window docked at `x` (Forever
--- smoke feedback S5), in the sheet frame's units: the strip's right edge past `x`, plus a margin, when
--- the shown mode tabs run down, start no further than STRIP_SLACK right of `x` and end past it (a
--- `window.dockGap` included); else 0. The
--- window widens by this much and keeps its contents right of it (modules/Window.lua), so the tabs lie
--- over an empty band of the window's own background. The sheet button sits in the same column, as
--- wide as a tab, so the tabs' edges are the strip's. Retail has no such strip: always 0 there.
--- @param x number|nil the window's left edge, in the sheet frame's units
--- @return number
local function retailStripInset() return 0 end

local function foreverStripInset(x)
    if not x then return 0 end
    local tabs = shownModeTabs()
    if #tabs == 0 or Sheet.StripAcross(tabs) then return 0 end
    local sheetScale = scaleOf(Sheet.Frame())
    local left, right
    for _, tab in ipairs(tabs) do
        local l, r = plainEdge(tab, "GetLeft"), plainEdge(tab, "GetRight")
        if l and r then
            local k = scaleOf(tab) / sheetScale
            l, r = l * k, r * k
            left = left and math.min(left, l) or l
            right = right and math.max(right, r) or r
        end
    end
    if not (left and right) or left > x + STRIP_SLACK or right <= x then return 0 end
    return right - x + STRIP_MARGIN
end
Sheet.StripInset = NS.PerClient({ retail = retailStripInset, forever = foreverStripInset })
