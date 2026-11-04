local _, NS = ...
-- modules/Bar.lua — NS.Bar: the outfit bar (design §7.7, INV §7.6; OutfitterBar.lua at 7ea3dc3).
--
-- A HUD (skinning-§6) and a free-floating display: a persisted position, the Master Lock and the
-- position Reset (BP §11). It stores no colors, so it owes no FromSkin rows. ONE container,
-- `OutfitterRebornBar` (strata HUD, movable, clamped, toplevel), holds a backplate, one row frame per
-- category with shown outfits (`OutfitterRebornBarRow1..2`), the drag handle above it and, in test
-- mode, the test strip along its top. The buttons are pooled per row (modules/Bar_Buttons.lua builds
-- them): each render releases every row and acquires exactly one button per outfit, which fixes the
-- legacy `_ButtonBar`'s extra button.
--
-- LAYOUT is modules/Bar_Layout.lua's arithmetic over the Layout and Icons rows (smoke round 2 design
-- G6): icons per line, padding, spacing, icon size, and the grow direction. "Automatic" grows AWAY
-- from the saved corner (QUADRANT): a bar saved at a right corner grows left, one saved at a bottom
-- corner grows up; an explicit direction pins the corner SavePosition saves at, and a write to it
-- re-saves the place there, so the bar neither jumps nor flips. The position is
-- `profile.windows.bar` (design §3.4), the storage of the `bar.position` row (settings/OutfitBar.lua),
-- and its one writer is that row's set through NS.SetByPath (architecture-§5): SavePosition on a drag
-- stop (that corner, in screen pixels, divided by the effective scale on the way back, as legacy
-- stored it), `/or set|reset bar.position` and Reset position (NS.ApplyDefault). The set decodes into
-- a new table each time, so a reset COPIES the default (legacy aliased it, so a reset after a drag
-- could do nothing: OutfitterBar.lua:107-115).
--
-- SHOWN = (bar.shown or test mode) and the Master visibility rule and not in a pet battle and not
-- stood down. The decision is made here and nowhere else, so a stood-down bar cannot be re-shown.
-- ALPHA is the Master alpha, times `bar.combatAlpha` in combat (PLAYER_STATE_CHANGED "combat"); at 0
-- the buttons take no mouse (frame-layering-§4: insecure frames, so legal in combat). The legacy fades
-- are kept: off the bar, the handle fades out over 0.3 s and the bar down to its alpha over 0.5 s.
--
-- REBUILDS are coalesced on one 0 s AceTimer flag: OUTFIT_WORN/REMOVED/ADDED/DELETED/EDITED/RENAMED,
-- SETTINGS_CHANGED for a `bar.*` or Master row, PREVIEW_CHANGED and PROFILE_CHANGED (which is also
-- the re-anchor a profile switch needs: a new profile carries its own `windows.bar`).
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits, NS.Preview.IsActive/Source,
-- NS.PlayerState.InCombat; the buttons call NS.Stack, NS.OutfitMenu, NS.OutfitTooltip, NS.Triggers.

local Bar = {}
NS.Bar = Bar

local L = NS.L
local Secrets = NS.Secrets
local LAYERS = NS.Constants.LAYERS
local Perf = NS.Perf

local MAX_ROWS = 2                      -- one per category
local HANDLE_FADE, BAR_FADE = 0.3, 0.5  -- StartFrameFades (OutfitterBar.lua:236-248)
local HANDLE_GAP = 2
local HANDLE_HEIGHT = 18                -- W.DragHandle's strip, when the frame cannot say

Bar.HANDLE_FADE, Bar.BAR_FADE = HANDLE_FADE, BAR_FADE

--- The direction a bar saved at each corner grows in: the sign of x, then of y.
local QUADRANT = {
    TOPLEFT = { 1, -1 }, TOPRIGHT = { -1, -1 }, BOTTOMLEFT = { 1, 1 }, BOTTOMRIGHT = { -1, 1 },
}
Bar.QUADRANT = QUADRANT

-- The Master rows that govern the bar (options-ui-§15); every `bar.*` row does too.
local MASTER = { scale = true, alpha = true, locked = true, visibility = true }
-- The grow-direction rows: a write re-saves the bar's place at the corner it implies.
local GROW = { ["bar.layout.growH"] = true, ["bar.layout.growV"] = true }
local GROW_X = { right = 1, left = -1 }
local GROW_Y = { down = -1, up = 1 }

-- handleFaded: the pointer left since the bar was last locked, so the handle rests faded out until
-- the next hover; a rebuild must not bring it back (the legacy handle showed only on hover).
local st = { active = false, inCombat = false, inPetBattle = false, hovered = false, handleFaded = false,
             timer = nil }
local bar, rows = nil, {}
local mod   -- the module's own bus target, with AceTimer and the pet-battle events on it

local function num(v, fallback) return Secrets.UnsecretNumber(v, fallback) end

local function level(frame) return num(frame:GetFrameLevel(), 0) end

-- ── reads ─────────────────────────────────────────────────────────────────────────────────────

--- The saved corner, or the default's when the stored one is not a corner.
local function position()
    local p = NS.db.profile.windows.bar
    if type(p) ~= "table" or not QUADRANT[p.point] then p = NS.defaults.profile.windows.bar end
    return p
end

local VISIBLE = {
    always      = function() return true end,
    never       = function() return false end,
    inCombat    = function() return st.inCombat end,
    outOfCombat = function() return not st.inCombat end,
}

--- The Master visibility rule; an unknown value reads as "always".
local function visibilityAllows()
    local rule = VISIBLE[NS.GetSetting("visibility")]
    return rule == nil or rule()
end

local function locked() return NS.GetSetting("locked") == true end

local function scale()
    local s = num(NS.GetSetting("scale"), 1)
    if s <= 0 then return 1 end
    return s
end

--- The direction the bar grows in, as QUADRANT's signs: the grow rows, "auto" the saved corner's.
--- @param p table|nil the saved place (nil reads it)
--- @return number gx, number gy
function Bar.Growth(p)
    local q = QUADRANT[(p or position()).point]
    return GROW_X[NS.GetSetting("bar.layout.growH")] or q[1], GROW_Y[NS.GetSetting("bar.layout.growV")] or q[2]
end

--- The height above the icons: the test strip while it shows.
--- @param strip boolean|nil
--- @return number
function Bar.HeaderHeight(strip)
    if strip then return NS.TEST_STRIP_HEIGHT end
    return 0
end

--- Bar_Layout's spec from the settings, for categories of `counts` icons.
--- @param counts number[]
--- @param strip boolean|nil
--- @return table
function Bar.LayoutSpec(counts, strip)
    local gx, gy = Bar.Growth()
    return {
        size = num(NS.GetSetting("bar.icons.size"), 32), spacing = num(NS.GetSetting("bar.layout.spacing"), 5),
        padding = num(NS.GetSetting("bar.layout.padding"), 4), perLine = num(NS.GetSetting("bar.layout.perLine"), 0),
        vertical = NS.GetSetting("bar.vertical") == true, labelH = 0, top = Bar.HeaderHeight(strip),
        minWidth = 0, gx = gx, gy = gy, counts = counts,
    }
end

--- Whether the bar is up: the one show decision (see the header).
--- @return boolean
function Bar.ShouldShow()
    if not st.active or NS.IsStoodDown() or st.inPetBattle then return false end
    if not visibilityAllows() then return false end
    return NS.GetSetting("bar.shown") == true or NS.Preview.IsActive() == true
end

--- The live source: each category's outfits in display order, without the ones whose trigger is
--- off (the one Disabled flag, design §3.3) or that are hidden from the bar (`bar.hide`).
Bar.LiveSource = {
    Rows = function()
        local out, O = {}, NS.Outfits
        for _, category in ipairs(O.Categories()) do
            local list = {}
            for _, rec in O.Each(category) do
                local off = rec.trigger and rec.trigger.disabled
                local hidden = rec.bar and rec.bar.hide
                if not off and not hidden then list[#list + 1] = rec end
            end
            out[#out + 1] = { categoryID = category, outfits = list }
        end
        return out
    end,
}

-- ── the frames ────────────────────────────────────────────────────────────────────────────────

local function fadeOut(frame, seconds, from, to)
    if frame and type(UIFrameFadeOut) == "function" then UIFrameFadeOut(frame, seconds, from, to) end
end

local function fadeStop(frame)
    if frame and type(UIFrameFadeRemoveFrame) == "function" then UIFrameFadeRemoveFrame(frame) end
end

local function newHandle(f)
    local handle = NS.MakeDragHandle(f, {
        label             = L["Outfit bar"],
        moveFrame         = f,
        canDrag           = function() return not locked() end,
        onDragStop        = function() Bar.SavePosition() end,
        onRightClick      = function() NS.OpenOptionsPanel("bar") end,
        tooltip           = { title = L["Outfit bar"], body = { L["Drag to move. Right-click for bar settings."] } },
        ignoreParentAlpha = true,
        level             = LAYERS.LEVEL.HANDLE,
    })
    if not handle then return nil end
    handle:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, HANDLE_GAP)
    handle:HookScript("OnEnter", function() Bar.HoverIn() end)
    handle:HookScript("OnLeave", function() Bar.HoverOut() end)
    handle:ApplyWidth(32)
    return handle
end

--- The container, built on the first render and kept: hidden at birth, so nothing shows before the
--- show decision says so.
local function ensureFrame()
    if bar then return bar end
    local f = CreateFrame("Frame", "OutfitterRebornBar", UIParent)
    f:Hide()
    f:SetFrameStrata(LAYERS.STRATA.HUD)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:SetScript("OnEnter", function() Bar.HoverIn() end)
    f:SetScript("OnLeave", function() Bar.HoverOut() end)
    f.bg = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.bg:SetAllPoints(f)
    NS.Skin.Panel(f.bg)
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", "OutfitterRebornBarRow" .. i, f)
        row:SetFrameLevel(level(f) + LAYERS.LEVEL.BAR_ROW)
        row:Hide()
        rows[i] = { frame = row, pool = NS.Pool.New() }
    end
    f.handle = newHandle(f)
    bar = f
    return f
end

--- The test strip, built the first time test mode shows the bar.
local function ensureStrip()
    if bar.strip == nil then
        local strip = NS.MakeTestStrip(bar, L["Test mode: sample outfits. Nothing is equipped or saved"])
        bar.strip = strip or false
        if strip then
            strip:SetFrameLevel(level(bar) + LAYERS.LEVEL.MARKER)
            strip:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            strip:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
        end
    end
    return bar.strip or nil
end

--- The container, or nil before the first render (for the suites and the skin survey).
function Bar.Frame() return bar end

--- The buttons handed out by the last render, row by row.
--- @return table[]
function Bar.Buttons()
    local out = {}
    for i = 1, #rows do
        for _, btn in ipairs(rows[i].pool.active) do out[#out + 1] = btn end
    end
    return out
end

-- ── render ────────────────────────────────────────────────────────────────────────────────────

local function anchor(p)
    bar:ClearAllPoints()
    local s = num(bar:GetEffectiveScale(), 1)
    if s <= 0 then s = 1 end
    bar:SetPoint(p.point, UIParent, p.point, (num(p.x, 0)) / s, (num(p.y, 0)) / s)
end

--- Place row frame `row` at layout block `b` and fill it with `outfits`, `size` px buttons at the
--- block's points (anchored to the bar's TOPLEFT, Bar_Layout's coordinates).
local function placeRow(row, b, outfits, size)
    local f = row.frame
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", bar, "TOPLEFT", b.x, -b.y)
    f:SetSize(b.w, b.h)
    f:Show()
    local buttonLevel = level(bar) + LAYERS.LEVEL.BAR_BUTTON
    for j, rec in ipairs(outfits) do
        local btn = NS.Pool.Acquire(row.pool, function() return Bar.NewButton(f) end)
        local p = b.icons[j]
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", bar, "TOPLEFT", p.x, -p.y)
        btn:SetSize(size, size)
        btn:SetFrameLevel(buttonLevel)
        Bar.SetButton(btn, rec)
    end
end

--- The rows a source answers, without the empty ones, at most one per row frame.
local function shownRows(source)
    local out = {}
    for _, row in ipairs(source.Rows() or {}) do
        if #out < MAX_ROWS and type(row.outfits) == "table" and #row.outfits > 0 then out[#out + 1] = row end
    end
    return out
end

--- Draw `source` (Bar.LiveSource or NS.Preview.Source): its rows, laid out by Bar_Layout from the
--- settings, the bar sized to them and anchored at the saved corner, with the test strip's height
--- above the rows while `strip` is set. Perf bucket `barRender`.
--- @param source table  answers Rows() -> { { categoryID, outfits = { rec, ... } }, ... }
--- @param strip boolean|nil
function Bar.Render(source, strip)
    local t0 = Perf.on and debugprofilestop()
    ensureFrame()
    for i = 1, MAX_ROWS do
        NS.Pool.ReleaseAll(rows[i].pool)
        rows[i].frame:Hide()
    end
    local list, counts = shownRows(source), {}
    for i, row in ipairs(list) do counts[i] = #row.outfits end
    local spec = Bar.LayoutSpec(counts, strip)
    local g = Bar.Layout.Compute(spec)
    for i, row in ipairs(list) do placeRow(rows[i], g.blocks[i], row.outfits, spec.size) end
    bar:SetSize(g.width, g.height)
    bar:SetScale(scale())
    anchor(position())
    bar.bg:SetShown(NS.GetSetting("bar.showBackground") ~= false)
    if t0 then Perf.Note("barRender", debugprofilestop() - t0) end
end

local function hideFrames()
    if not bar then return end
    fadeStop(bar)
    fadeStop(bar.handle)
    bar:Hide()
    if bar.handle then bar.handle:Hide() end
    if bar.strip then bar.strip:Hide() end
end

--- Make the bar what the settings, the latch and test mode say, now. Answers whether it is shown.
--- @return boolean
function Bar.Refresh()
    if st.timer and mod then mod:CancelTimer(st.timer) end
    st.timer = nil
    if not Bar.ShouldShow() then
        hideFrames()
        return false
    end
    local preview = NS.Preview.IsActive() == true
    Bar.Render(preview and NS.Preview.Source or Bar.LiveSource, preview)
    local strip = preview and ensureStrip()
    if strip then strip:Show() elseif bar.strip then bar.strip:Hide() end
    bar:Show()
    Bar.SetLocked(locked())
    Bar.ApplyAlpha()
    return true
end

local function runScheduled()
    st.timer = nil
    if NS.IsStoodDown() then return end
    Bar.Refresh()
end

--- Coalesce a refresh onto one 0 s timer. Nothing while suspended.
local function schedule()
    if not st.active or st.timer or not mod then return end
    st.timer = mod:ScheduleTimer(runScheduled, 0)
end

-- ── scale, alpha, lock, hover ─────────────────────────────────────────────────────────────────

--- The Master scale, applied and the bar re-anchored at it (the offsets are divided by it).
function Bar.ApplyScale()
    if not bar then return end
    bar:SetScale(scale())
    anchor(position())
end

--- The alpha the bar rests at: Master alpha, times `bar.combatAlpha` in combat.
--- @return number
function Bar.EffectiveAlpha()
    local a = num(NS.GetSetting("alpha"), 1)
    if st.inCombat then a = a * num(NS.GetSetting("bar.combatAlpha"), 1) end
    return a
end

--- Apply the resting alpha (full while hovered); at 0 the buttons and the container take no mouse.
--- A hover-out fade still running is stopped first, or its end alpha would overwrite this one.
function Bar.ApplyAlpha()
    if not bar then return end
    fadeStop(bar)
    local a = Bar.EffectiveAlpha()
    local mouse = a > 0
    bar:SetAlpha((st.hovered and mouse) and 1 or a)
    bar:EnableMouse(mouse)
    for _, btn in ipairs(Bar.Buttons()) do btn:EnableMouse(mouse) end
end

-- The container's clamp covers the handle above it while it shows, so a drag to the top edge can
-- never push the handle off screen (the legacy moved the drag bar itself, which kept it on).
local function clampHandle(shown)
    local top = 0
    if shown then
        local h = num(bar.handle:GetHeight(), 0)
        top = (h > 0 and h or HANDLE_HEIGHT) + HANDLE_GAP
    end
    bar:SetClampRectInsets(0, 0, top, 0)
end

--- Show the drag handle while unlocked and the bar is up; hide it while locked. Shown, it is at full
--- alpha until the pointer first leaves after an unlock, then faded until the next hover.
--- @param on boolean|nil  the lock; nil reads the setting
function Bar.SetLocked(on)
    if on == nil then on = locked() end
    local handle = bar and bar.handle
    if not handle then return end
    if on then st.handleFaded = false end
    local shown = not on and bar:IsShown() == true
    clampHandle(shown)
    if not shown then
        fadeStop(handle)
        handle:Hide()
        return
    end
    if not st.handleFaded then handle:SetAlpha(1) end
    handle:Show()
end

--- The pointer is over the bar, a button or the handle: everything at full alpha, the fades stopped.
function Bar.HoverIn()
    if not bar then return end
    st.hovered, st.handleFaded = true, false
    fadeStop(bar)
    fadeStop(bar.handle)
    if bar.handle and not locked() then bar.handle:SetAlpha(1) end
    Bar.ApplyAlpha()
end

--- The pointer left: the handle fades out over 0.3 s, the bar down to its alpha over 0.5 s.
function Bar.HoverOut()
    if not bar then return end
    st.hovered = false
    if bar.handle and not locked() then
        st.handleFaded = true
        fadeOut(bar.handle, HANDLE_FADE, 1, 0)
    end
    local a = Bar.EffectiveAlpha()
    if a ~= 1 and a > 0 then
        fadeOut(bar, BAR_FADE, 1, a)
    else
        bar:SetAlpha(a)
    end
end

-- ── position ──────────────────────────────────────────────────────────────────────────────────

--- The drag stop: save the corner the grow direction implies (the nearest screen corner on an axis
--- left Automatic), in screen pixels (OutfitterBar.lua:279-317), through the `bar.position` row's
--- write seam, then redraw grown from it. The seam's SETTINGS_CHANGED echo schedules one more redraw
--- (onSettings below), after the drag, at the corner just saved.
--- @return table|nil the saved { point, x, y }
function Bar.SavePosition()
    if not bar then return nil end
    local s, u = num(bar:GetEffectiveScale(), 1), num(UIParent:GetEffectiveScale(), 1)
    local left, right = num(bar:GetLeft(), 0) * s, num(bar:GetRight(), 0) * s
    local top, bottom = num(bar:GetTop(), 0) * s, num(bar:GetBottom(), 0) * s
    local uLeft, uRight = num(UIParent:GetLeft(), 0) * u, num(UIParent:GetRight(), 0) * u
    local uTop, uBottom = num(UIParent:GetTop(), 0) * u, num(UIParent:GetBottom(), 0) * u
    local gx = GROW_X[NS.GetSetting("bar.layout.growH")] or (((left + right) >= (uLeft + uRight)) and -1 or 1)
    local gy = GROW_Y[NS.GetSetting("bar.layout.growV")] or (((top + bottom) < (uTop + uBottom)) and 1 or -1)
    local vert, y = "TOP", top - uTop
    if gy > 0 then vert, y = "BOTTOM", bottom - uBottom end
    local horiz, x = "LEFT", left - uLeft
    if gx < 0 then horiz, x = "RIGHT", right - uRight end
    NS.SetByPath("bar.position", NS.EncodeBarPosition({ point = vert .. horiz, x = x, y = y }))
    if st.active then Bar.Refresh() end
    return NS.db.profile.windows.bar
end

-- ── receivers ─────────────────────────────────────────────────────────────────────────────────

local function onSettings(_, path)
    if type(path) ~= "string" then return end
    -- A new grow direction keeps the bar where it is: its place, re-saved at the corner it implies.
    if GROW[path] and bar and bar:IsShown() then Bar.SavePosition() end
    if MASTER[path] or path:find("^bar%.") then schedule() end
end

local function onPlayerState(_, key, value)
    if key ~= "combat" then return end
    st.inCombat = value == true
    if not st.active then return end
    Bar.ApplyAlpha()
    schedule()
end

local function onGameEvent(event)
    if NS.IsStoodDown() then return end
    st.inPetBattle = event == "PET_BATTLE_OPENING_START"
    if st.active then Bar.Refresh() end
end

local REBUILD = { "OUTFIT_WORN", "OUTFIT_REMOVED", "OUTFIT_ADDED", "OUTFIT_DELETED", "OUTFIT_EDITED",
                  "OUTFIT_RENAMED", "PREVIEW_CHANGED", "PROFILE_CHANGED" }
local GAME_EVENTS = { "PET_BATTLE_OPENING_START", "PET_BATTLE_OVER" }

local function ensureListeners()
    if mod then return end
    mod = NS.NewBusTarget()
    LibStub("AceTimer-3.0"):Embed(mod)
    for _, key in ipairs(REBUILD) do mod:RegisterMessage(NS.MSG[key], schedule) end
    mod:RegisterMessage(NS.MSG.SETTINGS_CHANGED, onSettings)
    mod:RegisterMessage(NS.MSG.PLAYER_STATE_CHANGED, onPlayerState)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

--- The stand-down (design §5.12): the pet-battle events and the pending rebuild go, and the bar hides.
function Bar.Suspend()
    st.active, st.hovered = false, false
    if mod then
        mod:UnregisterAllEvents()
        if st.timer then mod:CancelTimer(st.timer) end
    end
    st.timer = nil
    hideFrames()
end

--- The stand-up: register from scratch and redraw from the current settings on the next frame.
function Bar.Resume()
    ensureListeners()
    Bar.Suspend()
    for _, event in ipairs(GAME_EVENTS) do
        NS.SafeRegisterEvent(mod, event, onGameEvent, NS.rejectedEvents)
    end
    st.inCombat = NS.PlayerState.InCombat() == true
    st.inPetBattle = false
    st.active = true
    schedule()
end
