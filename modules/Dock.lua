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
-- drew over it, which hid it on the stock sheet. It is a plain button: no secure frame is touched. It
-- shows with the paper doll and hides with it, since its parent outlives the Character tab.
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
-- NS.Stack.Select, NS.Dialogs.CloseAll, NS.IconChooser.Close, NS.CloseMenu, NS.SecureQueue,
-- NS.Sheet.Refresh/DockRight/Frame/ButtonAnchor.

local Dock = { wanted = false, suspended = false, followDisabled = false, built = false,
               Y_OFFSET = 0, FOLLOW_INTERVAL = 0.05 }
NS.Dock = Dock

local L = NS.L
local LEVEL = NS.Constants.LAYERS.LEVEL
local Perf = NS.Perf

local WINDOW_NAME = "OutfitterRebornWindow"

local holder, button, driver, win, events
local installed = false
local sinceTick = 0
local toldCombat = false

local function locked() return NS.Compat.InCombatLockdown() end

--- @return table|nil the sheet holder, `OutfitterRebornSheetHolder`, once installed
function Dock.Holder() return holder end

--- @return boolean the window is on screen
function Dock.IsShown()
    return win ~= nil and win:IsShown() == true
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

local function onWindowShow()
    sinceTick = 0
    driver:Show()
    driver:SetScript("OnUpdate", followTick)
end

local function onWindowHide()
    driver:SetScript("OnUpdate", nil)
    driver:Hide()
    -- Escape (UISpecialFrames) hides it behind the dock's back: that is a close, unless combat did it.
    -- A close takes the Name and Rebuild dialogs with it (Outfitter.lua:1491-1504); the combat
    -- suspend keeps them (O30).
    if not Dock.suspended then
        Dock.wanted = false
        NS.Dialogs.CloseAll("host")
    end
    NS.Stack.Select(nil)
    NS.CloseMenu()
    NS.IconChooser.Close("opener")
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

-- Re-anchor the sheet button where the current sheet wants it, over the close button. Out of the
-- stand-down only; a plain button, so allowed in combat.
local function placeButton()
    local point, rel, relPoint, x, y, size = NS.Sheet.ButtonAnchor()
    button:ClearAllPoints()
    button:SetPoint(point, rel, relPoint, x, y)
    button:SetSize(size, size)
    local close = CharacterFrameCloseButton
    local base = close and NS.SafeNumber(close:GetFrameLevel(), 0) or NS.SafeNumber(CharacterFrame:GetFrameLevel(), 0)
    button:SetFrameLevel(base + LEVEL.SHEET_BUTTON_OVER_CLOSE)
    button:Show()
end

local function onSheetShow()
    if NS.IsStoodDown() then return end
    NS.Sheet.Refresh()
    placeButton()
    Dock.Refresh()
end

-- "Doesn't reappear next open" (Outfitter.lua:1500-1504).
local function onSheetHide()
    if NS.IsStoodDown() then return end
    button:Hide()
    local wasShown = Dock.IsShown()
    Dock.wanted = false
    Dock.Refresh()
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
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.icon:SetTexture(NS.Constants.DEFAULT_OUTFIT_ICON)
    -- Borderless, like the tab icons beside it; the glyph in the accent token, which follows the skin.
    NS.Skin.Button(button, { noBg = true, noBorder = true, tokens = { icon = "of.sheet.button" } })
    button:SetScript("OnClick", function() if not NS.IsStoodDown() then Dock.Toggle() end end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Toggle the Outfitter window"])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    if events then events:UnregisterAllEvents() end
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
    if not events then events = LibStub("AceEvent-3.0"):Embed({}) end
    events:UnregisterAllEvents()
    for event in pairs(EVENTS) do NS.SafeRegisterEvent(events, event, onEvent, NS.rejectedEvents) end
    if PaperDollFrame:IsVisible() == true then
        NS.Sheet.Refresh()
        placeButton()
    end
    Dock.suspended = false
    Dock.Refresh()
end
