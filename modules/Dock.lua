local _, NS = ...
-- modules/Dock.lua — NS.Dock: the sheet holder and button, the window's show model, its follow and its
-- layer sync (design §7.2, H4, INV §7.1, §16.1-§16.2).
--
-- DOCKED, NEVER ANCHORED. Every list row owns a secure button (modules/Window_Rows.lua), and a
-- protected frame restricts both the frames it is parented to and the frames it is anchored to: a
-- window parented or anchored to PaperDollFrame would make the sheet unmovable for every other
-- addon. So the window is parented to UIParent and follows the sheet: one UIParent-relative SetPoint
-- at the sheet's right and top (no ClearAllPoints), re-issued from a 0.05 s follow on an owned driver
-- frame only when the corner moved (Outfitter.lua:1355-1488). If the client refuses even that anchor,
-- the window parks in the holder: usable, but the sheet is pinned (the old fallback, :1477-1488).
-- The corner is NS.Sheet.DockRight(): the right edge of the visible sheet (CharacterFrame, or
-- Chonky's backdrop) or of an open Chonky side panel, and the sheet's top. The window's top is flush
-- with the sheet's (Y_OFFSET 0; sheet and window feedback design G3).
--
-- THE SHEET BUTTON sits right of the Equipment Manager tab (NS.Sheet.ButtonAnchor; design G1),
-- re-anchored on every sheet show, since the sheet kind can change with another addon. It is parented
-- to CharacterFrame and set above the close button's level: in the sheet holder it shared
-- PaperDollFrame's level (useParentLevel), and the frame's NineSlice (500) and close button (510)
-- drew over it, which hid it on the stock sheet. It is a plain button: no secure frame is touched.
-- On WoW Forever it is one more tab of the outer side-tab strip (ruling D8), made from that strip's
-- template: the "sidetab" look below.
-- It wears the HOST'S look, not the skin (smoke round 2 design G2; the accepted deviation
-- DEV-SKIN-SHEET-BUTTON, skinning-§1/§9, docs/ARCHITECTURE.md -> Documented deviations): on the stock
-- and Chonky sheets a hand-built copy of PaperDollSidebarTabTemplate (its OnLoad indexes
-- PAPERDOLL_SIDEBARS by id, so it cannot be inherited), selected while the window shows; on
-- EllesmereUI a text label in its tab style, idle, hover and active (its accent) as _paintTopButton
-- paints its own. The button builds both looks once and placeButton picks one (NS.Sheet.ButtonAnchor).
--
-- THE PAPER-DOLL PANE. The window belongs to the Character tab, and on Retail so does the button: the
-- Reputation and Currency tabs hide PaperDollFrame but not CharacterFrame, the button's parent, so the
-- doll's OnHide hides the button (and the window, which needs the doll shown) and its OnShow
-- re-resolves the sheet kind and re-anchors. On WoW Forever the button is one more tab of the mode
-- strip, which shows on every tab, so it follows CharacterFrame instead (Forever smoke feedback S4);
-- a click from another tab opens the Character tab and the window (Dock.Open). A sheet addon may build its frames after the doll's OnShow (EllesmereUI builds
-- its tabs from a CharacterFrame OnShow hook on the first open, EllesmereUIBlizzardSkin_
-- CharacterSheet.lua:4907, :3171), so the sheet show looks again on the next frame and re-anchors
-- only when the kind moved.
--
-- TEST MODE (smoke round 2 design G7, D9, D10; smoke round 3 E3). While NS.Preview is on, the window
-- shows its sample outfits under its own strip (NS.Window.SetTestMode) whether or not the player asked
-- for it: beside the sheet when the paper doll is up, else ALONE, in the screen center (Dock.AloneSpot,
-- in UIParent's units), through the same one TOPLEFT -> UIParent BOTTOMLEFT point and the same
-- Refresh, so never in lockdown (test mode is refused in combat and ends at PLAYER_REGEN_DISABLED,
-- before lockdown). The follow then reads the alone spot, not the hidden sheet's. Alone, and only
-- alone, the window DRAGS for the length of the test session (out of lockdown; the D10 clause as E3
-- amends it): the drop becomes the session's alone spot, re-issued as the dock's one point, and is
-- never saved (the client's user-placed flag is cleared after the drop, so layout-local.txt keeps
-- nothing); the next session starts centered. Combat hides the window before lockdown, and the hide
-- stops a move in progress. X, Escape or the sheet button's close hide it for the rest of that test session
-- (`testDismissed`) without ending the mode, which still ends only on its own switch, combat or Reset
-- all (preview-mode). Entering test mode clears the selection, so the sheet's slot boxes and the
-- footer's Slots buttons never act on a real outfit while the samples show. A window parked in the
-- holder (followDisabled) cannot stand alone; the bar still shows the samples.
--
-- THE OUTFIT WINDOW PAGE (smoke round 3 E11). `window.sheetButton` off keeps the sheet button hidden
-- (still anchored, so turning it on shows it in place); `window.dockGap` moves the docked window that
-- many sheet units right of the sheet's edge (never the alone test window); `window.drawer` is read by
-- the drawer itself, which follows the paper doll (Forever smoke feedback S7). A write of any `window.*` row or a profile switch re-shows the button and syncs
-- the drawer here; the follow's corner compare picks up the gap.
--
-- THE ONLY SHOW AND HIDE. Dock.Refresh is the one place this addon shows or hides
-- `OutfitterRebornWindow`. It never does so in combat lockdown (design §7.0 rule 2): the window hides
-- inside PLAYER_REGEN_DISABLED, while protected calls are still allowed, and comes back at
-- PLAYER_REGEN_ENABLED if the sheet is still open. The dialogs stay open through that (O30).
--
-- LAYERS. Detached, the window no longer inherits its strata and level from the character sheet, so
-- it copies them: the holder's strata and its level + DOCK_OVER_HOST, which stacks it exactly as a
-- real child would, so anything that covers the sheet covers the window too. The sheet's level
-- changes whenever it is raised over another panel, so this runs from the follow as well as on show.
-- The strata always comes from the host, never a fixed one. The writes go through NS.SecureQueue: the
-- window holds secure children.
--
-- Every hook and handler reads the latch first (H26). The hooks are installed once, on the first
-- stand-up (Resume), and stay; a stand-down drops the events and the follow and hides the window.
--
-- CALLS (at call time; design §12): NS.Window, NS.WindowRows.DisarmSecure, NS.SlotEnables.MaybeRestack,
-- NS.Stack.Select, NS.Dialogs.CloseAll, NS.IconBrowser.Close, NS.CloseMenu, NS.SecureQueue,
-- NS.Preview.IsActive, NS.Sheet.Refresh/Kind/DockRight/Frame/ButtonAnchor, NS.QuickSlots.DrawerSync (the doll's show
-- and hide turn the equipment drawer outward and back, the window's show and hide the flyout tint, a
-- regen catches up a lockdown; modules/QuickSlots.lua).

local Dock = { wanted = false, suspended = false, followDisabled = false, built = false, testDismissed = false,
               Y_OFFSET = 0, FOLLOW_INTERVAL = 0.05 }
NS.Dock = Dock

local L = NS.L
local LEVEL = NS.Constants.LAYERS.LEVEL
local Perf = NS.Perf

local WINDOW_NAME = "OutfitterRebornWindow"

local holder, button, driver, win, events
local placedKind -- the sheet kind the button was last anchored for
local placedLook -- the look it wears there: "tab" | "text" | "sidetab" | "chonkytab"
local installed = false
local sinceTick = 0
local toldCombat = false

local function locked() return NS.Compat.InCombatLockdown() end

--- @return table|nil the sheet holder, `OutfitterRebornSheetHolder`, once installed
function Dock.Holder() return holder end

--- @return boolean the window's own shown flag is set
function Dock.IsShown()
    return win ~= nil and win:IsShown() == true
end

--- The window is on screen: shown, and every parent too. A window parked in the sheet holder
--- (Dock.Attach's fallback) keeps its shown flag when the sheet hides it.
--- @return boolean
function Dock.IsVisible()
    return win ~= nil and win:IsVisible() == true
end

--- The paper doll is on screen (the outward drawer's gate, modules/QuickSlots.lua).
--- @return boolean
function Dock.DollVisible()
    return PaperDollFrame:IsVisible() == true
end

--- Test mode wants the window: on, and not dismissed for this test session.
--- @return boolean
function Dock.TestWanted()
    return NS.Preview.IsActive() == true and not Dock.testDismissed
end

--- Whether the window should be up: not suspended for combat, standing up, out of lockdown; then
--- beside the shown sheet when wanted or in test mode, or alone in test mode with the sheet closed.
function Dock.ShouldShow()
    if Dock.suspended or NS.IsStoodDown() or locked() then return false end
    if PaperDollFrame:IsVisible() == true then return Dock.wanted or Dock.TestWanted() end
    return Dock.TestWanted() and not Dock.followDisabled
end

-- ── position and layers ───────────────────────────────────────────────────────────────────────

--- Where the window stands alone in test mode, in UIParent's units: the spot the player dropped it
--- at this session, else its TOPLEFT with the window centered on the screen (smoke round 3 E3). The
--- size is the one Window set, so the center holds before the client lays the window out. nil, nil
--- while UIParent has no rect.
--- @return number|nil x, number|nil top
function Dock.AloneSpot()
    local spot = Dock.testSpot
    if spot then return spot[1], spot[2] end
    local right, top = NS.SafeNumber(UIParent:GetRight(), nil), NS.SafeNumber(UIParent:GetTop(), nil)
    if not (right and top) then return nil, nil end
    local w, h = NS.Window.Size()
    return (right - w) / 2, (top + h) / 2
end

-- The Outfit Window page's gap between the sheet and the window (smoke round 3 E11), in the sheet's
-- units; 0 when the store answers nothing usable.
local function dockGap()
    local gap = NS.SafeNumber(NS.GetSetting("window.dockGap"), 0)
    return gap > 0 and gap or 0
end

-- The corner and the frame whose units it is in: the sheet's, `window.dockGap` right of its edge, or,
-- standing alone in test mode with the sheet closed, the alone spot, in UIParent's. The follow compares
-- this corner, so a new gap re-docks the window on its next tick.
local function corner()
    if PaperDollFrame:IsVisible() ~= true and Dock.TestWanted() then
        local x, top = Dock.AloneSpot()
        return x, top, UIParent
    end
    local x, top = NS.Sheet.DockRight()
    if x then x = x + dockGap() end
    return x, top, NS.Sheet.Frame()
end

-- The one SetPoint, at the corner times the anchor-to-own scale ratio.
local function positionWindow()
    local right, top, host = corner()
    if not right or not top then
        -- The sheet has never been laid out: park it; it is placed properly when the sheet opens.
        Dock.followRight, Dock.followTop = nil, nil
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        return
    end
    local scale = NS.SafeNumber(win:GetEffectiveScale(), 1)
    local hostScale = NS.SafeNumber(host:GetEffectiveScale(), 1)
    if scale <= 0 then scale = 1 end
    Dock.followRight, Dock.followTop = right, top
    win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", right * hostScale / scale, top * hostScale / scale + Dock.Y_OFFSET)
end

--- Place the window beside the sheet. Out of combat only; a refused anchor parks it in the holder.
function Dock.Attach()
    if not win or Dock.followDisabled or locked() then return end
    if pcall(positionWindow) then return end
    Dock.followDisabled = true
    win:SetParent(holder)
    NS.Window.Relevel(NS.SafeNumber(win:GetFrameLevel(), 0))
    NS.Debug("Dock", "the window's anchor was refused; it now sits in the sheet holder")
end

--- Copy the holder's strata and level + DOCK_OVER_HOST onto the window (a cached compare), and let
--- the slot checkboxes restack (allowed in combat: they hold no secure frame).
function Dock.ApplyLayers()
    NS.SlotEnables.MaybeRestack()
    if not (win and holder) then return end
    local strata = NS.Secrets.PlainString(holder:GetFrameStrata())
    if not strata then return end   -- a secret strata is never copied (the secret guard)
    local level = NS.SafeNumber(holder:GetFrameLevel(), 0) + LEVEL.DOCK_OVER_HOST
    if strata == Dock.lastStrata and level == Dock.lastLevel then return end
    NS.SecureQueue.Run("dock.layers", function()
        win:SetFrameStrata(strata)
        win:SetFrameLevel(level)
        NS.Window.Relevel(level)
        Dock.lastStrata, Dock.lastLevel = strata, level
    end)
end

-- ── the test-mode drag (smoke round 3 E3) ─────────────────────────────────────────────────────

-- Only the alone test window moves: docked, it follows the sheet; parked in the holder, it cannot
-- stand alone; in lockdown its secure children make the move a blocked action.
local function canDrag()
    if locked() or NS.IsStoodDown() or Dock.followDisabled then return false end
    return Dock.TestWanted() and PaperDollFrame:IsVisible() ~= true
end

local function onDragStart()
    if not canDrag() then return end
    Dock.moving = true
    win:StartMoving()
end

--- End a move in progress: the drop is the session's alone spot (in UIParent's units), the client's
--- user-placed flag is cleared so nothing is saved, and the dock's one point is issued again over
--- whatever the move left. From the drop, and from a hide (combat's comes before lockdown).
function Dock.EndDrag()
    if not Dock.moving or locked() then return end
    Dock.moving = false
    win:StopMovingOrSizing()
    win:SetUserPlaced(false)
    local left, top = NS.SafeNumber(win:GetLeft(), nil), NS.SafeNumber(win:GetTop(), nil)
    if left and top then
        local ratio = NS.SafeNumber(win:GetEffectiveScale(), 1) / NS.SafeNumber(UIParent:GetEffectiveScale(), 1)
        Dock.testSpot = { left * ratio, top * ratio }
    end
    win:ClearAllPoints()
    Dock.Attach()
end

local function installDrag()
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetDontSavePosition(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", onDragStart)
    win:SetScript("OnDragStop", function() Dock.EndDrag() end)
end

-- ── the follow ────────────────────────────────────────────────────────────────────────────────

local function cornerMoved()
    if Dock.followDisabled then return false end
    local right, top = corner()
    if not right or not top then return false end
    return right ~= Dock.followRight or top ~= Dock.followTop
end

local function followTick(_, elapsed)
    if NS.IsStoodDown() then return end
    sinceTick = sinceTick + NS.SafeNumber(elapsed, 0)
    if sinceTick < Dock.FOLLOW_INTERVAL then return end
    sinceTick = 0
    local t0 = Perf.on and debugprofilestop()
    Dock.ApplyLayers()
    if cornerMoved() then Dock.Attach() end
    NS.Window.RenderIfDirty()
    if t0 then Perf.Note("dockFollow", debugprofilestop() - t0) end
end

-- ── the sheet button's host look (smoke round 2 design G2; deviation DEV-SKIN-SHEET-BUTTON) ──────

-- PaperDollSidebarTabTemplate's art and coords (wow-ui-source@297d7aa:Interface/AddOns/
-- Blizzard_UIPanels_Game/Mainline/PaperDollFrame.xml:393-430), and the selected TabBg
-- PaperDollFrame_UpdateSidebarTabs writes (PaperDollFrame.lua:2673-2694). Chonky's own extra tab,
-- MyTransmogButton, is built by hand from the same file (characterSheet.lua:878-922).
local TAB_ART = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs"
local TAB_BG = { 0.015625, 0.796875, 0.61328125, 0.78125 }
local TAB_BG_SELECTED = { 0.015625, 0.796875, 0.7890625, 0.95703125 }
local TAB_HIDER = { 0.015625, 0.546875, 0.11328125, 0.1875 }
local TAB_HIGHLIGHT = { 0.015625, 0.5, 0.1953125, 0.31640625 }
-- The icon inside the tab, cropped as item art is (smoke round 3 E10). The neighbors' pictures in
-- PaperDollSidebarTabs are 25-26 wide (Titles x 3-28, Equipment Manager x 4-28 at alpha > 0.5), and
-- TabBg's face inside its bevel is 29 x 30 (x 3..32, y 1..31 of the tab), so a full-bleed 26 x 26
-- reads as their size and leaves the bevel showing; round 2's 30 x 30 covered it. It centers where the
-- neighbor's icon does (NS.Sheet.TabIconOffset), re-read on each placing.
local TAB_ICON_SIZE = 26
local ICON_CROP = { 0.07, 0.93, 0.07, 0.93 }
-- EllesmereUI's label face size (CreateEUIButton: SetFont(fontPath, 10, "")).
local EUI_FONT_SIZE = 10

-- WoW Forever's outer side-tab strip (ruling D8): the button is made from the strip's own
-- LargeSideTabButtonTemplate, as a CheckButton, when the client has the template; its own scripts
-- replace the template's, so it never joins the strip's mode switching (CharacterModeTabButtonMixin).
-- The template (F-UI Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1008, SidePanelTabButtonMixin)
-- carries an `Icon` with NO size: its OnLoad only centers it, and the mode tabs get theirs from
-- fillToInterior (CharacterFrame.xml:394-401, SetFillToInterior's 50 px square). So the template's
-- Icon takes the outfit icon through SetFillToInterior, as the strip's own tabs do; without the
-- template the button's own icon draws centered. The selected state goes through SetChecked.
local SIDE_TAB_TEMPLATE = NS.PerClient({ forever = "LargeSideTabButtonTemplate" })
local SIDE_TAB_ICON_SIZE = 32 -- PROBE P27: the strip's icon size is unread

-- ChonkyCharacterSheet's skinned mode tab (Forever smoke feedback S1; CCS-F core/styles.lua:844-947):
-- the template's art hidden, a CCS_BG fill in the neighbor's file and coords, tinted, the icon at 42 of
-- the tab's 48 masked round, and a yellow highlight at 38 of 48 while selected. Its mask and highlight
-- files are its own; the fill and the colors are copied off the strip live (NS.Sheet.ChonkyTabArt,
-- ChonkyTabColors), since Chonky's tables are private.
local CCS_MEDIA = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\Frame\\"
local CCS_MASK, CCS_HIGHLIGHT = CCS_MEDIA .. "buttonmask1.blp", CCS_MEDIA .. "buttonhighlight1.png"
local CCS_ICON, CCS_GLOW, CCS_TAB = 42, 38, 48
-- The template regions Chonky hides on a tab it skins (core/styles.lua:849-868).
local TEMPLATE_ART = { "Left", "LeftActive", "LeftHighlight", "Middle", "MiddleActive", "MiddleHighlight", "Right",
                       "RightActive", "RightHighlight", "Text", "Background", "HighlightTexture", "Icon", "Mask",
                       "SelectedTexture", "TabGlow" }
local STATE_ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture" }

-- The template to build the sheet button from, when this client has it; nil on Retail.
local function sheetButtonTemplate()
    local xml = _G.C_XMLUtil
    if not SIDE_TAB_TEMPLATE or type(xml) ~= "table" or type(xml.GetTemplateInfo) ~= "function" then return nil end
    if xml.GetTemplateInfo(SIDE_TAB_TEMPLATE) == nil then return nil end
    return SIDE_TAB_TEMPLATE
end

-- The template's own icon texture, when it carries one.
local function templateIcon()
    local icon = rawget(button, "Icon")
    if type(icon) == "table" and type(icon.SetTexture) == "function" then return icon end
    return nil
end

local function tabTexture(layer, w, h, coords)
    local t = button:CreateTexture(nil, layer)
    t:SetTexture(TAB_ART)
    t:SetSize(w, h)
    t:SetTexCoord(unpack(coords))
    return t
end

-- The template's own art at full alpha, or out of sight while the button wears Chonky's skin. Alpha
-- only: the regions stay where the template put them.
local function templateArt(visible)
    local a = visible and 1 or 0
    for _, key in ipairs(TEMPLATE_ART) do
        local r = rawget(button, key)
        if type(r) == "table" and type(r.SetAlpha) == "function" then r:SetAlpha(a) end
    end
    for _, getter in ipairs(STATE_ART) do
        local t = type(button[getter]) == "function" and button[getter](button)
        if type(t) == "table" and type(t.SetAlpha) == "function" then t:SetAlpha(a) end
    end
end

-- Chonky's look, built the first time a strip in its skin asks for it.
local function buildChonkyLook()
    if button.ccsBg then return end
    button.ccsBg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    button.ccsBg:SetAllPoints(button)
    button.ccsIcon = button:CreateTexture(nil, "ARTWORK")
    button.ccsIcon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.ccsIcon:SetTexture(NS.Constants.DEFAULT_OUTFIT_ICON)
    if type(button.CreateMaskTexture) == "function" then
        local mask = button:CreateMaskTexture()
        mask:SetTexture(CCS_MASK)
        mask:SetAllPoints(button)
        -- Every Texture answers AddMaskTexture in the client; a stand-in that does not draws it square.
        if pcall(function() button.ccsIcon:AddMaskTexture(mask) end) then button.ccsMask = mask end
    end
    button.ccsGlow = button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.ccsGlow:SetTexture(CCS_HIGHLIGHT)
    button.ccsGlow:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.ccsGlow:SetVertexColor(1, 1, 0, 1)
end

-- Chonky's look shown or hidden; shown, it takes the neighbor's fill and the tab's proportions.
local function chonkyLook(on)
    if not on then
        if button.ccsBg then
            for _, key in ipairs({ "ccsBg", "ccsIcon", "ccsGlow" }) do button[key]:Hide() end
        end
        return
    end
    buildChonkyLook()
    local tex, coords = NS.Sheet.ChonkyTabArt()
    if tex then button.ccsBg:SetTexture(tex) end
    if coords and #coords >= 4 then button.ccsBg:SetTexCoord(unpack(coords)) end
    local w = NS.SafeNumber(button:GetWidth(), CCS_TAB)
    if w <= 0 then w = CCS_TAB end
    button.ccsIcon:SetSize(w * CCS_ICON / CCS_TAB, w * CCS_ICON / CCS_TAB)
    button.ccsGlow:SetSize(w * CCS_GLOW / CCS_TAB, w * CCS_GLOW / CCS_TAB)
    button.ccsBg:Show()
    button.ccsIcon:Show()
end

-- Both looks, built once; placeButton shows one.
local function buildLooks()
    button.TabBg = tabTexture("BACKGROUND", 50, 43, TAB_BG)
    button.TabBg:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -9, -2)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(TAB_ICON_SIZE, TAB_ICON_SIZE)
    button.icon:SetTexture(NS.Constants.DEFAULT_OUTFIT_ICON)
    button.icon:SetTexCoord(unpack(ICON_CROP))
    button.Hider = tabTexture("OVERLAY", 34, 19, TAB_HIDER)
    button.Hider:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
    button.Highlight = tabTexture("HIGHLIGHT", 31, 31, TAB_HIGHLIGHT)
    button.Highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -3)
    button.label = button:CreateFontString(nil, "OVERLAY")
    -- A face before the text: the client refuses SetText on a template-less string with no font
    -- ("Font not set"). applyLook swaps in EllesmereUI's own face on each text placing.
    button.label:SetFont(STANDARD_TEXT_FONT, EUI_FONT_SIZE, "")
    button.label:SetPoint("TOP", button, "TOP", 0, 0)
    button.label:SetText(L["Outfits"])
end

-- The tab: unselected, or selected while the window shows (PaperDollFrame_UpdateSidebarTabs' rule).
local function paintTab(selected)
    button.TabBg:SetTexCoord(unpack(selected and TAB_BG_SELECTED or TAB_BG))
    button.Hider:SetShown(not selected)
    button.Highlight:SetShown(not selected)
end

-- The label: EllesmereUI's accent while the window shows, white on hover, white at 0.6 idle
-- (_paintTopButton, EllesmereUIBlizzardSkin_CharacterSheet.lua:3133-3145).
local function paintLabel(selected)
    if selected then
        local r, g, b = NS.Sheet.EUIAccent()
        button.label:SetTextColor(r, g, b, 1)
    elseif button.hovered then
        button.label:SetTextColor(1, 1, 1, 1)
    else
        button.label:SetTextColor(1, 1, 1, 0.6)
    end
end

-- The side tab (Forever): checked while the window shows, as the strip's own tabs are for their mode.
local function paintSideTab(selected)
    if type(button.SetChecked) == "function" then button:SetChecked(selected) end
end

-- Chonky's skin: the selected tab's color and the yellow glow while the window shows, the selected
-- color without the glow under the pointer, an unselected tab's color idle (core/styles.lua:931-947).
local function paintChonkyTab(selected)
    local idle, active = NS.Sheet.ChonkyTabColors()
    local c = (selected or button.hovered) and active or idle
    button.ccsBg:SetVertexColor(c[1], c[2], c[3], c[4])
    button.ccsGlow:SetShown(selected)
end

-- Repaint the look the button wears for the window's state now.
local function paintButton()
    if not button then return end
    local selected = Dock.IsShown()
    if placedLook == "text" then return paintLabel(selected) end
    if placedLook == "sidetab" then return paintSideTab(selected) end
    if placedLook == "chonkytab" then
        -- A CheckButton's own checked art stays out of sight; the glow is the selected state.
        if type(button.SetChecked) == "function" then button:SetChecked(false) end
        return paintChonkyTab(selected)
    end
    paintTab(selected)
end

-- Show one look's regions and hide the other's; the label copies EllesmereUI's face on each placing.
local function applyLook(look)
    local tab = look == "tab"
    for _, key in ipairs({ "TabBg", "icon", "Hider", "Highlight" }) do button[key]:SetShown(tab) end
    button.label:SetShown(look == "text")
    templateArt(look ~= "chonkytab")
    chonkyLook(look == "chonkytab")
    if look == "chonkytab" then
        button.icon:Hide()
    elseif look == "sidetab" then
        local own = templateIcon()
        if own then
            own:SetTexture(NS.Constants.DEFAULT_OUTFIT_ICON)
            -- An unsized texture draws nothing: size it as the mode tabs size theirs.
            if type(button.SetFillToInterior) == "function" then
                button:SetFillToInterior(true)
            else
                own:SetSize(SIDE_TAB_ICON_SIZE, SIDE_TAB_ICON_SIZE)
            end
        end
        button.icon:SetShown(own == nil)
        button.icon:SetSize(SIDE_TAB_ICON_SIZE, SIDE_TAB_ICON_SIZE)
        button.icon:ClearAllPoints()
        button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    elseif tab then
        button.icon:ClearAllPoints()
        button.icon:SetPoint("CENTER", button, "CENTER", NS.Sheet.TabIconOffset())
    else
        local source = NS.Sheet.EUILabelText()
        local face = source and source:GetFont()
        button.label:SetFont(face or STANDARD_TEXT_FONT, EUI_FONT_SIZE, "")
    end
    placedLook = look
    paintButton()
end

local function onWindowShow()
    sinceTick = 0
    driver:Show()
    driver:SetScript("OnUpdate", followTick)
    NS.QuickSlots.DrawerSync() -- the flyout tint follows the window
    paintButton()
end

local function onWindowHide()
    Dock.EndDrag()
    paintButton()
    driver:SetScript("OnUpdate", nil)
    driver:Hide()
    -- The flyout tint is for the open window only (DEV-SKIN-FLYOUT-TINT); the drawer is the doll's.
    NS.QuickSlots.DrawerSync()
    -- Escape (UISpecialFrames) hides it behind the dock's back: that is a close, unless combat did it.
    -- A close takes the Name and Rebuild dialogs with it (Outfitter.lua:1491-1504); the combat
    -- suspend keeps them (O30).
    -- In test mode the close dismisses the test window for the session (D10): Refresh must not bring
    -- it straight back. Not the sheet's close taking a window parked in its holder down with it: that
    -- window cannot stand alone, and the sheet's next open docks it again.
    if not Dock.suspended then
        Dock.wanted = false
        local sheetTookIt = Dock.followDisabled and PaperDollFrame:IsVisible() ~= true
        if NS.Preview.IsActive() and not sheetTookIt then Dock.testDismissed = true end
        NS.Dialogs.CloseAll("host")
    end
    NS.Stack.Select(nil)
    NS.CloseMenu()
    NS.IconBrowser.Close("opener")
end

-- ── the show model ────────────────────────────────────────────────────────────────────────────

function Dock.build()
    if Dock.built then return end
    Dock.built = true
    win = NS.Window.Build()
    win:HookScript("OnShow", onWindowShow)
    win:HookScript("OnHide", onWindowHide)
    installDrag()
    table.insert(UISpecialFrames, WINDOW_NAME)
end

--- THE ONLY place OutfitterRebornWindow is shown or hidden; never in lockdown.
function Dock.Refresh()
    if locked() then return end
    if Dock.ShouldShow() then
        Dock.build()
        NS.Window.SetTestMode(NS.Preview.IsActive())
        Dock.Attach()
        Dock.ApplyLayers()
        win:Show()
        NS.Window.MarkDirty(true)
        NS.Window.RenderIfDirty()
    elseif win and win:IsShown() then
        win:Hide()
    end
end

--- Open the window, showing the sheet first when it is hidden (INV §7.1). In lockdown it says once
--- that the window opens when combat ends, and keeps the wish.
function Dock.Open()
    if NS.IsStoodDown() then return false end
    Dock.wanted = true
    if PaperDollFrame:IsVisible() ~= true then ToggleCharacter("PaperDollFrame") end
    if locked() then
        if not toldCombat then
            toldCombat = true
            NS.Print(L["The Outfitter window opens when combat ends."])
        end
        return false
    end
    Dock.Refresh()
    return Dock.IsShown()
end

function Dock.Close()
    Dock.wanted = false
    if NS.Preview.IsActive() then Dock.testDismissed = true end
    Dock.Refresh()
end

--- Open or close the window. `closeSheet`: a close takes the character sheet down too (the launcher's
--- ToggleUI(true), Outfitter.lua:6699-6708); the sheet goes first, so its OnHide closes the window.
--- @param closeSheet boolean|nil
function Dock.Toggle(closeSheet)
    if Dock.IsShown() or (Dock.wanted and locked()) then
        if closeSheet and PaperDollFrame:IsVisible() == true then ToggleCharacter("PaperDollFrame") end
        return Dock.Close()
    end
    return Dock.Open()
end

-- ── hooks and events ──────────────────────────────────────────────────────────────────────────

-- WoW Forever's button follows CharacterFrame, not the paper doll (Forever smoke feedback S4): its
-- mode-tab strip shows on every tab (Reputation, Skills, PvP, Currency, Statistics), and so does the
-- button, one more tab of it. Retail's belongs to the doll's sidebar.
local BUTTON_FOLLOWS_FRAME = NS.PerClient({ retail = false, forever = true })

-- The Outfit Window page's sheet-button switch (smoke round 3 E11).
local function buttonWanted() return NS.GetSetting("window.sheetButton") ~= false end

-- Re-anchor the sheet button where the current sheet wants it, over the close button, in that
-- sheet's look, and show it unless the Outfit Window page turned it off (anchored either way, so the
-- switch shows it in place). Out of the stand-down only; a plain button, so allowed in combat.
local function placeButton()
    local point, rel, relPoint, x, y, w, h, look, scale = NS.Sheet.ButtonAnchor()
    button:ClearAllPoints()
    button:SetScale(NS.SafeNumber(scale, 1) > 0 and NS.SafeNumber(scale, 1) or 1)
    button:SetPoint(point, rel, relPoint, x, y)
    button:SetSize(w, h)
    applyLook(look)
    local close = CharacterFrameCloseButton
    local base = close and NS.SafeNumber(close:GetFrameLevel(), 0) or NS.SafeNumber(CharacterFrame:GetFrameLevel(), 0)
    button:SetFrameLevel(base + LEVEL.SHEET_BUTTON_OVER_CLOSE)
    button:SetShown(buttonWanted())
    placedKind = NS.Sheet.Kind()
end

-- The next frame's look: a sheet addon that built its frames after the doll's OnShow moves the button.
local function recheckSheet()
    if NS.IsStoodDown() or PaperDollFrame:IsVisible() ~= true then return end
    if NS.Sheet.Kind() ~= placedKind then placeButton() end
end

-- Forever (S4): CharacterFrame's show places the button, and places it again on the next frame,
-- once a sheet addon's own OnShow has laid the strip out (Chonky lays and skins it there).
local function replaceOnFrame()
    if NS.IsStoodDown() or CharacterFrame:IsVisible() ~= true then return end
    placeButton()
end

local function onFrameShow()
    if NS.IsStoodDown() then return end
    NS.Sheet.Refresh()
    placeButton()
    if events then events:ScheduleTimer(replaceOnFrame, 0) end
end

local function onFrameHide()
    if NS.IsStoodDown() then return end
    button:Hide()
end

local function onSheetShow()
    if NS.IsStoodDown() then return end
    NS.Sheet.Refresh()
    placeButton()
    if events then events:ScheduleTimer(recheckSheet, 0) end
    Dock.Refresh()
    -- The outward drawer is the doll's, whether or not the window is up (Forever smoke feedback S7).
    NS.QuickSlots.DrawerSync()
end

-- "Doesn't reappear next open" (Outfitter.lua:1500-1504).
local function onSheetHide()
    if NS.IsStoodDown() then return end
    -- Forever's button stays with its strip on the other tabs (S4); CharacterFrame's hide takes it.
    if BUTTON_FOLLOWS_FRAME then paintButton() else button:Hide() end
    local wasShown = Dock.IsShown()
    Dock.wanted = false
    Dock.Refresh()
    -- The drawer is the doll's (Forever smoke feedback S7): it goes back to Blizzard's with the doll.
    NS.QuickSlots.DrawerSync()
    NS.CloseMenu()
    -- A shown window's own OnHide closed the dialogs; this covers a window hidden for combat (O30).
    if not wasShown then NS.Dialogs.CloseAll("host") end
end

-- Test mode on: a fresh session's window (not dismissed, centered), and no selection for the samples
-- to act on. On or off, Refresh shows, re-docks or hides the window and swaps its chrome (never in
-- lockdown).
local function onPreviewChanged(_, on)
    if NS.IsStoodDown() then return end
    Dock.testSpot = nil
    if on then
        Dock.testDismissed = false
        NS.Stack.Select(nil)
    end
    Dock.Refresh()
end

-- An Outfit Window row's write or a profile switch (smoke round 3 E11): the sheet button shows or
-- hides in place while the paper doll is up (a plain button, so in combat too), and the drawer follows
-- `window.drawer` (DrawerSync writes nothing in lockdown; the regen syncs it). The gap is the follow's
-- (corner), the list's sections and marks Window's own receiver.
local function onWindowSettings()
    if NS.IsStoodDown() then return end
    local host = BUTTON_FOLLOWS_FRAME and CharacterFrame or PaperDollFrame
    if button and host:IsVisible() == true then button:SetShown(buttonWanted()) end
    NS.QuickSlots.DrawerSync()
end

local function onSettingsChanged(_, path)
    if type(path) == "string" and path:find("^window%.") then onWindowSettings() end
end

local function onRegenDisabled()
    if NS.IsStoodDown() then return end
    if win and win:IsShown() then
        NS.WindowRows.DisarmSecure()
        Dock.suspended = true
        win:Hide()
    end
end

local function onRegenEnabled()
    if NS.IsStoodDown() then return end
    Dock.suspended = false
    toldCombat = false
    NS.SecureQueue.Flush()
    Dock.Refresh()
    -- A doll shown or hidden in lockdown left the drawer as it was (Forever smoke feedback S7).
    NS.QuickSlots.DrawerSync()
end

local function buildSheet()
    holder = CreateFrame("Frame", "OutfitterRebornSheetHolder", PaperDollFrame)
    holder:SetAllPoints(PaperDollFrame)
    holder:EnableMouse(false)
    local template = sheetButtonTemplate()
    button = CreateFrame(template and "CheckButton" or "Button", "OutfitterRebornSheetButton", CharacterFrame, template)
    button:Hide()
    -- The host's look, never the skin's (DEV-SKIN-SHEET-BUTTON): no NS.Skin call on this button.
    buildLooks()
    -- The repaint undoes a CheckButton's own click toggle when the window did not change (Forever).
    button:SetScript("OnClick", function()
        if not NS.IsStoodDown() then Dock.Toggle() end
        paintButton()
    end)
    button:SetScript("OnEnter", function(self)
        self.hovered = true
        paintButton()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Toggle the Outfitter window"])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered = false
        paintButton()
        GameTooltip:Hide()
    end)
    -- Draws nothing: its OnUpdate is the follow, set only while the window is shown.
    driver = CreateFrame("Frame", "OutfitterRebornDockDriver", UIParent)
    driver:Hide()
end

--- The holder, the button, the driver and the sheet hooks: once per session.
function Dock.Install()
    if installed then return end
    installed = true
    buildSheet()
    PaperDollFrame:HookScript("OnShow", onSheetShow)
    PaperDollFrame:HookScript("OnHide", onSheetHide)
    if BUTTON_FOLLOWS_FRAME then
        CharacterFrame:HookScript("OnShow", onFrameShow)
        CharacterFrame:HookScript("OnHide", onFrameHide)
    end
    -- The bus record drops and replays this receiver across a stand-down.
    local bus = NS.NewBusTarget()
    if bus then
        bus:RegisterMessage(NS.MSG.PREVIEW_CHANGED, onPreviewChanged)
        bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, onSettingsChanged)
        bus:RegisterMessage(NS.MSG.PROFILE_CHANGED, onWindowSettings)
    end
    NS.Window.Install()
end

local EVENTS = { PLAYER_REGEN_DISABLED = onRegenDisabled, PLAYER_REGEN_ENABLED = onRegenEnabled }

local function onEvent(event) EVENTS[event]() end

--- The lifecycle's stand-down (design §5.12): the events and the follow go, the button hides, and the
--- window closes (queued past lockdown, since it holds secure children).
function Dock.Suspend()
    Dock.wanted, toldCombat = false, false
    if events then events:UnregisterAllEvents(); events:CancelAllTimers() end
    if driver then driver:SetScript("OnUpdate", nil) end
    if button then button:Hide() end
    if not (win and win:IsShown()) then return end
    if locked() then
        NS.SecureQueue.Run("dock.hide", function() win:Hide() end)
    else
        win:Hide()
    end
end

--- The stand-up: the hooks (once), the two combat events, the button.
function Dock.Resume()
    Dock.Install()
    if not events then events = LibStub("AceTimer-3.0"):Embed(LibStub("AceEvent-3.0"):Embed({})) end
    events:UnregisterAllEvents()
    for event in pairs(EVENTS) do NS.SafeRegisterEvent(events, event, onEvent, NS.rejectedEvents) end
    local host = BUTTON_FOLLOWS_FRAME and CharacterFrame or PaperDollFrame
    if host:IsVisible() == true then
        NS.Sheet.Refresh()
        placeButton()
    end
    Dock.suspended = false
    Dock.Refresh()
end
