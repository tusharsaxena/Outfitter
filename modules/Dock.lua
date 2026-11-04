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
-- It wears the HOST'S look, not the skin (smoke round 2 design G2; the accepted deviation
-- DEV-SKIN-SHEET-BUTTON, skinning-§1/§9, docs/ARCHITECTURE.md -> Documented deviations): on the stock
-- and Chonky sheets a hand-built copy of PaperDollSidebarTabTemplate (its OnLoad indexes
-- PAPERDOLL_SIDEBARS by id, so it cannot be inherited), selected while the window shows; on
-- EllesmereUI a text label in its tab style, idle, hover and active (its accent) as _paintTopButton
-- paints its own. The button builds both looks once and placeButton picks one (NS.Sheet.ButtonAnchor).
--
-- THE PAPER-DOLL PANE. The button and the window belong to the Character tab: the Reputation and
-- Currency tabs hide PaperDollFrame but not CharacterFrame, the button's parent, so the doll's OnHide
-- hides the button (and the window, which needs the doll shown) and its OnShow re-resolves the sheet
-- kind and re-anchors. A sheet addon may build its frames after the doll's OnShow (EllesmereUI builds
-- its tabs from a CharacterFrame OnShow hook on the first open, EllesmereUIBlizzardSkin_
-- CharacterSheet.lua:4907, :3171), so the sheet show looks again on the next frame and re-anchors
-- only when the kind moved.
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
-- NS.Sheet.Refresh/Kind/DockRight/Frame/ButtonAnchor, NS.QuickSlots.DrawerSync (the window's show and
-- hide turn the left column's equipment drawer outward and back; modules/QuickSlots.lua).

local Dock = { wanted = false, suspended = false, followDisabled = false, built = false,
               Y_OFFSET = 0, FOLLOW_INTERVAL = 0.05 }
NS.Dock = Dock

local L = NS.L
local LEVEL = NS.Constants.LAYERS.LEVEL
local Perf = NS.Perf

local WINDOW_NAME = "OutfitterRebornWindow"

local holder, button, driver, win, events
local placedKind -- the sheet kind the button was last anchored for
local placedLook -- the look it wears there: "tab" | "text"
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

--- Whether the window should be up: wanted, not suspended for combat, standing up, the sheet showing.
function Dock.ShouldShow()
    return Dock.wanted and not Dock.suspended and not NS.IsStoodDown()
        and PaperDollFrame:IsVisible() == true and not locked()
end

-- ── position and layers ───────────────────────────────────────────────────────────────────────

local function corner() return NS.Sheet.DockRight() end

-- The one SetPoint, at the sheet's corner times the anchor-to-own scale ratio.
local function positionWindow()
    local right, top = corner()
    if not right or not top then
        -- The sheet has never been laid out: park it; it is placed properly when the sheet opens.
        Dock.followRight, Dock.followTop = nil, nil
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        return
    end
    local scale = NS.SafeNumber(win:GetEffectiveScale(), 1)
    local hostScale = NS.SafeNumber(NS.Sheet.Frame():GetEffectiveScale(), 1)
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
    local strata = holder:GetFrameStrata()
    local level = NS.SafeNumber(holder:GetFrameLevel(), 0) + LEVEL.DOCK_OVER_HOST
    if strata == Dock.lastStrata and level == Dock.lastLevel then return end
    NS.SecureQueue.Run("dock.layers", function()
        win:SetFrameStrata(strata)
        win:SetFrameLevel(level)
        NS.Window.Relevel(level)
        Dock.lastStrata, Dock.lastLevel = strata, level
    end)
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
-- The icon inside the tab: Chonky's 30 x 30 centered (its full-bleed tab icon), cropped as item art is.
local TAB_ICON_SIZE = 30
local ICON_CROP = { 0.07, 0.93, 0.07, 0.93 }
-- EllesmereUI's label face size (CreateEUIButton: SetFont(fontPath, 10, "")).
local EUI_FONT_SIZE = 10

local function tabTexture(layer, w, h, coords)
    local t = button:CreateTexture(nil, layer)
    t:SetTexture(TAB_ART)
    t:SetSize(w, h)
    t:SetTexCoord(unpack(coords))
    return t
end

-- Both looks, built once; placeButton shows one.
local function buildLooks()
    button.TabBg = tabTexture("BACKGROUND", 50, 43, TAB_BG)
    button.TabBg:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -9, -2)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(TAB_ICON_SIZE, TAB_ICON_SIZE)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetTexture(NS.Constants.DEFAULT_OUTFIT_ICON)
    button.icon:SetTexCoord(unpack(ICON_CROP))
    button.Hider = tabTexture("OVERLAY", 34, 19, TAB_HIDER)
    button.Hider:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
    button.Highlight = tabTexture("HIGHLIGHT", 31, 31, TAB_HIGHLIGHT)
    button.Highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -3)
    button.label = button:CreateFontString(nil, "OVERLAY")
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

-- Repaint the look the button wears for the window's state now.
local function paintButton()
    if not button then return end
    local selected = Dock.IsShown()
    if placedLook == "text" then return paintLabel(selected) end
    paintTab(selected)
end

-- Show one look's regions and hide the other's; the label copies EllesmereUI's face on each placing.
local function applyLook(look)
    local tab = look ~= "text"
    for _, key in ipairs({ "TabBg", "icon", "Hider", "Highlight" }) do button[key]:SetShown(tab) end
    button.label:SetShown(not tab)
    if not tab then
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
    NS.QuickSlots.DrawerSync()
    paintButton()
end

local function onWindowHide()
    paintButton()
    driver:SetScript("OnUpdate", nil)
    driver:Hide()
    -- The outward drawer is for the open window only (sheet and window feedback design G8).
    NS.QuickSlots.DrawerSync()
    -- Escape (UISpecialFrames) hides it behind the dock's back: that is a close, unless combat did it.
    -- A close takes the Name and Rebuild dialogs with it (Outfitter.lua:1491-1504); the combat
    -- suspend keeps them (O30).
    if not Dock.suspended then
        Dock.wanted = false
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
    table.insert(UISpecialFrames, WINDOW_NAME)
end

--- THE ONLY place OutfitterRebornWindow is shown or hidden; never in lockdown.
function Dock.Refresh()
    if locked() then return end
    if Dock.ShouldShow() then
        Dock.build()
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

-- Re-anchor the sheet button where the current sheet wants it, over the close button, in that
-- sheet's look. Out of the stand-down only; a plain button, so allowed in combat.
local function placeButton()
    local point, rel, relPoint, x, y, w, h, look = NS.Sheet.ButtonAnchor()
    button:ClearAllPoints()
    button:SetPoint(point, rel, relPoint, x, y)
    button:SetSize(w, h)
    applyLook(look)
    local close = CharacterFrameCloseButton
    local base = close and NS.SafeNumber(close:GetFrameLevel(), 0) or NS.SafeNumber(CharacterFrame:GetFrameLevel(), 0)
    button:SetFrameLevel(base + LEVEL.SHEET_BUTTON_OVER_CLOSE)
    button:Show()
    placedKind = NS.Sheet.Kind()
end

-- The next frame's look: a sheet addon that built its frames after the doll's OnShow moves the button.
local function recheckSheet()
    if NS.IsStoodDown() or PaperDollFrame:IsVisible() ~= true then return end
    if NS.Sheet.Kind() ~= placedKind then placeButton() end
end

local function onSheetShow()
    if NS.IsStoodDown() then return end
    NS.Sheet.Refresh()
    placeButton()
    if events then events:ScheduleTimer(recheckSheet, 0) end
    Dock.Refresh()
end

-- "Doesn't reappear next open" (Outfitter.lua:1500-1504).
local function onSheetHide()
    if NS.IsStoodDown() then return end
    button:Hide()
    local wasShown = Dock.IsShown()
    Dock.wanted = false
    Dock.Refresh()
    -- A window parked in the holder was hidden with the sheet, so its own Hide above fired no OnHide:
    -- the drawer is put back here as well (design G8).
    NS.QuickSlots.DrawerSync()
    NS.CloseMenu()
    -- A shown window's own OnHide closed the dialogs; this covers a window hidden for combat (O30).
    if not wasShown then NS.Dialogs.CloseAll("host") end
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
end

local function buildSheet()
    holder = CreateFrame("Frame", "OutfitterRebornSheetHolder", PaperDollFrame)
    holder:SetAllPoints(PaperDollFrame)
    holder:EnableMouse(false)
    button = CreateFrame("Button", "OutfitterRebornSheetButton", CharacterFrame)
    button:Hide()
    -- The host's look, never the skin's (DEV-SKIN-SHEET-BUTTON): no NS.Skin call on this button.
    buildLooks()
    button:SetScript("OnClick", function() if not NS.IsStoodDown() then Dock.Toggle() end end)
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
    if PaperDollFrame:IsVisible() == true then
        NS.Sheet.Refresh()
        placeButton()
    end
    Dock.suspended = false
    Dock.Refresh()
end
