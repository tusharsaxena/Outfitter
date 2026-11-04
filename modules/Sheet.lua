local _, NS = ...
-- modules/Sheet.lua — NS.Sheet: which character sheet is up and where on it the outfit button and the
-- window go (sheet and window feedback design G1-G3). Three sheets: the stock one, EllesmereUI's
-- skinned sheet and ChonkyCharacterSheet. READS ONLY: it creates, anchors, shows and hides nothing;
-- modules/Dock.lua asks it on every sheet show and from the follow.
--
-- DETECTION. A sheet addon counts only when it is loaded AND the frame it builds is there and shown,
-- so a sheet addon whose skin is off falls back to the stock anchors instead of anchoring to a frame
-- that is hidden or was never built:
--   eui     EllesmereUIBlizzardSkin loaded and EUI_CharSheet_Equipment shown. With the "blizzard"
--           Character Sheet style it never builds its tabs (EllesmereUIBlizzardSkin_CharacterSheet.lua
--           :13-28), and it hides them off the Character tab (:1044-1047).
--   chonky  ChonkyCharacterSheet loaded and CharacterFrameBgbg shown. During combat or M+
--           (AreSecretsDisabled) it defers its setup (core/events.lua:414-425), so the backdrop that
--           CCS.CreateChonkyCharacterBG builds (core/styles.lua:1072-1107) may not be up.
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
-- CALLS (at call time): NS.Compat.IsAddOnLoaded, NS.SafeNumber.

local Sheet = {}
NS.Sheet = Sheet

-- The stock sheet's Equipment Manager tab: PaperDollSidebarTabTemplate is 33 x 35, and Tab3 sits at
-- PaperDollSidebarTabs BOTTOMRIGHT -30,0 (wow-ui-source@297d7aa:Interface/AddOns/
-- Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393-394, :475-503).
local STOCK_TAB = "PaperDollSidebarTab3"
local STOCK_TAB_SIZE = 33
local STOCK_GAP = 4
-- EllesmereUI's Equipment text tab, the last of its three (Character / Titles / Equipment).
local EUI_TAB = "EUI_CharSheet_Equipment"
local EUI_GAP, EUI_SIZE = 2, 20
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

-- A named frame that exists and is shown, else nil.
local function shownFrame(name)
    local f = _G[name]
    if type(f) ~= "table" or type(f.IsShown) ~= "function" then return nil end
    if f:IsShown() ~= true then return nil end
    return f
end

--- @return string "stock" | "eui" | "chonky"
function Sheet.Kind()
    if not loaded then Sheet.Refresh() end
    if loaded.eui and shownFrame(EUI_TAB) then return "eui" end
    if loaded.chonky and shownFrame(CHONKY_BACKDROP) then return "chonky" end
    return "stock"
end

--- @return table the visible sheet: CharacterFrame for stock and EllesmereUI, Chonky's backdrop for Chonky
function Sheet.Frame()
    if Sheet.Kind() == "chonky" then return _G[CHONKY_BACKDROP] end
    return CharacterFrame
end

-- PaperDollSidebarTab3's square side, its smaller dimension; the template's when it reads nothing.
local function stockTabSize(tab)
    local w, h = tab:GetSize()
    w, h = NS.SafeNumber(w, 0), NS.SafeNumber(h, 0)
    local size = math.min(w, h)
    if size <= 0 then return STOCK_TAB_SIZE end
    return size
end

--- Where the outfit button goes: right of the Equipment Manager tab on the stock and Chonky sheets
--- (Chonky keeps Blizzard's sidebar tabs), right of the Equipment text tab on EllesmereUI. Without
--- the stock tab (another addon removed it) the button keeps its old place, left of the close X.
--- @return string point, table relFrame, string relPoint, number x, number y, number size
function Sheet.ButtonAnchor()
    if Sheet.Kind() == "eui" then
        return "LEFT", _G[EUI_TAB], "RIGHT", EUI_GAP, 0, EUI_SIZE
    end
    local tab = _G[STOCK_TAB]
    if type(tab) == "table" then
        return "LEFT", tab, "RIGHT", STOCK_GAP, 0, stockTabSize(tab)
    end
    return "RIGHT", CharacterFrameCloseButton, "LEFT", -2, 0, 22
end

local function scaleOf(f)
    local s = NS.SafeNumber(f:GetEffectiveScale(), 1)
    if s <= 0 then return 1 end
    return s
end

--- Where the window docks: the right edge of the sheet, or of the rightmost shown Chonky side panel,
--- and the sheet's top, both in the sheet frame's (Sheet.Frame()'s) units. nil, nil while the sheet
--- has never been laid out.
--- @return number|nil x, number|nil top
function Sheet.DockRight()
    local frame = Sheet.Frame()
    local right = NS.SafeNumber(frame:GetRight(), nil)
    local top = NS.SafeNumber(frame:GetTop(), nil)
    if not right or not top then return nil, nil end
    if not loaded.chonky then return right, top end
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
