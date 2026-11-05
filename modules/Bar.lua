local _, NS = ...
-- modules/Bar.lua — NS.Bar: the outfit bar (design §7.7, INV §7.6; OutfitterBar.lua at 7ea3dc3).
--
-- A HUD (skinning-§6) and a free-floating display: a persisted position, the Master Lock and the
-- position Reset (BP §11). ONE container, `OutfitterRebornBar` (strata HUD, movable, clamped,
-- toplevel), wears a Ka0s window's look with a header (modules/Bar_Chrome.lua: the Shell chrome or the
-- player's plate, the title band with its title, lock and close, the drag strip and, in test mode,
-- the test strip under the band), and holds one row frame per category with shown outfits (one for
-- them all, unlabeled, while the Layout tab's Grouping is Collapsed: smoke round 3 E9)
-- (`OutfitterRebornBarRow1..2`). The buttons are pooled per row (modules/Bar_Buttons.lua builds them):
-- each render releases every row and acquires exactly one button per outfit, which fixes the legacy
-- `_ButtonBar`'s extra button. Its colors each carry a FromSkin companion (skinning-§6).
--
-- LAYOUT is modules/Bar_Layout.lua's arithmetic over the Layout and Icons rows (smoke round 2 design
-- G6): icons per line, padding, spacing, icon size, and the grow direction. "Automatic" grows AWAY
-- from the saved corner (QUADRANT): a bar saved at a right corner grows left, one saved at a bottom
-- corner grows up; an explicit direction pins the corner SavePosition saves at, and a write to it
-- re-saves the place there, so the bar neither jumps nor flips (a place written at another corner,
-- by a reset or a profile switch, is re-saved there on the next draw: Bar.CornerDisagrees). The position is
-- `profile.windows.bar` (design §3.4), the storage of the `bar.position` row (settings/OutfitBar.lua),
-- and its one writer is that row's set through NS.SetByPath (architecture-§5): SavePosition on a drag
-- stop (that corner, in screen pixels, divided by the effective scale on the way back, as legacy
-- stored it), `/or set|reset bar.position` and Reset position (NS.ApplyDefault). The set decodes into
-- a new table each time, so a reset COPIES the default (legacy aliased it, so a reset after a drag
-- could do nothing: OutfitterBar.lua:107-115).
--
-- SHOWN = (in test mode: not dismissed for this test session; else bar.shown) and the Master
-- visibility rule and not in a pet battle and not stood down. The decision is made here and nowhere
-- else, so a stood-down bar cannot be re-shown.
--
-- TEST MODE'S DISMISSAL (the bar's half of design D10; the window's is Dock.testDismissed). While test
-- mode is on, the four player hide paths (the header's close X, `/or bar hide` and `toggle`, the Toggle
-- outfit bar key) go through Bar.SetTestShown: they dismiss the bar for the rest of THAT test session
-- (`st.testDismissed`, session-only, never saved) and never write `bar.shown`, so a player whose bar was
-- on still has it when test mode ends. `/or bar show` (and toggle or the key while dismissed) brings it
-- back the same way. Neither ends test mode (preview-mode). The flag clears on every PREVIEW_CHANGED
-- and on the stand-down, so after test mode, by any route, the bar follows `bar.shown` again.
-- TEST MODE'S PLACE (smoke round 3 E3). For the length of a test session the bar starts just left of
-- the alone test window (its TOPRIGHT TEST_GAP left of NS.Dock.AloneSpot, worked out at the session's
-- first draw and held in `st.testPlace`, never saved), so the two never stack. It stays draggable: a
-- drag stop saves the place as it always does, and from then on the session draws the saved place.
-- While the test place holds, nothing re-saves it as the player's (CornerDisagrees and a grow-direction
-- write leave the saved place alone), and test mode's end, by any route, draws the saved place again.
-- ALPHA is the Master alpha, times `bar.combatAlpha` in combat (PLAYER_STATE_CHANGED "combat"); at 0
-- the buttons take no mouse (frame-layering-§4: insecure frames, so legal in combat). The legacy fade
-- is kept: off the bar, it fades down to its alpha over 0.5 s.
--
-- REBUILDS are coalesced on one 0 s AceTimer flag: OUTFIT_WORN/REMOVED/ADDED/DELETED/EDITED/RENAMED,
-- SETTINGS_CHANGED for a `bar.*` or Master row, PREVIEW_CHANGED, PROFILE_CHANGED (which is also the
-- re-anchor a profile switch needs: a new profile carries its own `windows.bar`) and a skin change
-- (NS.Skin.OnLooksChanged: the band's height and the skin's colors move with it).
--
-- A MENU THE BAR OPENED GOES WITH IT. A right click opens the outfit menu on the shared popup
-- (NS.OpenMenu), which no Hide of the bar reaches; every path that hides the bar (`/or bar hide` and
-- `toggle`, the Toggle outfit bar key and the header's close X, through `bar.shown`, or in test mode
-- through the session's dismissal; the stand-down through Suspend; test mode's end, a pet battle, the visibility rule) ends in hideFrames,
-- which closes that menu, and only that one (NS.CloseMenuFrom with Bar.IsButton), so a menu the
-- window opened stays up (core/WidgetsSetup.lua). Left open after `/or disable`, its rows would
-- still write saved data.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits, NS.Preview.IsActive/Source,
-- NS.PlayerState.InCombat, NS.CloseMenuFrom; the buttons call NS.Stack, NS.OutfitMenu,
-- NS.OutfitTooltip, NS.Triggers.

local Bar = {}
NS.Bar = Bar

local Secrets = NS.Secrets
local LAYERS = NS.Constants.LAYERS
local Perf = NS.Perf

local MAX_ROWS = 2                      -- one per category
local BAR_FADE = 0.5                    -- StartFrameFades (OutfitterBar.lua:236-248)

Bar.BAR_FADE = BAR_FADE

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

local st = { active = false, inCombat = false, inPetBattle = false, hovered = false, timer = nil,
             testDismissed = false, testPlace = nil }
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

-- The gap between the test bar's right edge and the alone test window's left, in UIParent's units.
local TEST_GAP = 8

--- The session's test place: { point = "TOPRIGHT", x, y } in screen pixels from UIParent's TOPRIGHT,
--- as SavePosition writes a place; nil outside test mode, after a drag (st.testPlace false), or while
--- the window's spot is not known yet (worked out again at the next draw).
local function testPlace()
    if NS.Preview.IsActive() ~= true or st.testPlace == false then return nil end
    if st.testPlace then return st.testPlace end
    local x, top = NS.Dock.AloneSpot()
    local uRight, uTop = num(UIParent:GetRight(), nil), num(UIParent:GetTop(), nil)
    if not (x and top and uRight and uTop) then return nil end
    local u = num(UIParent:GetEffectiveScale(), 1)
    st.testPlace = { point = "TOPRIGHT", x = (x - TEST_GAP - uRight) * u, y = (top - uTop) * u }
    return st.testPlace
end

--- Where the bar is drawn: the session's test place, else the saved one.
local function placed() return testPlace() or position() end

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
    local q = QUADRANT[(p or placed()).point]
    return GROW_X[NS.GetSetting("bar.layout.growH")] or q[1], GROW_Y[NS.GetSetting("bar.layout.growV")] or q[2]
end

--- Bar_Layout's spec from the settings, for categories of `counts` icons.
--- @param counts number[]
--- @param strip boolean|nil
--- @return table
function Bar.LayoutSpec(counts, strip)
    local gx, gy = Bar.Growth()
    -- A value that is no number lays out at the profile default (smoke round 3 E8's 8 and 4).
    local D = NS.defaults.profile.bar.layout
    return {
        size = num(NS.GetSetting("bar.icons.size"), 32), spacing = num(NS.GetSetting("bar.layout.spacing"), D.spacing),
        padding = num(NS.GetSetting("bar.layout.padding"), D.padding), perLine = num(NS.GetSetting("bar.layout.perLine"), 0),
        vertical = NS.GetSetting("bar.vertical") == true, labelH = Bar.LabelHeight(), top = Bar.HeaderHeight(strip),
        minWidth = Bar.Layout.MIN_WIDTH, gx = gx, gy = gy, counts = counts,
    }
end

--- Whether the bar is up: the one show decision (see the header).
--- @return boolean
function Bar.ShouldShow()
    if not st.active or NS.IsStoodDown() or st.inPetBattle then return false end
    if not visibilityAllows() then return false end
    if NS.Preview.IsActive() == true then return not st.testDismissed end
    return NS.GetSetting("bar.shown") == true
end

--- Whether the player has the bar on: in test mode, not dismissed for this test session; else
--- `bar.shown`. What `/or bar toggle` and the Toggle outfit bar key flip.
--- @return boolean
function Bar.PlayerWants()
    if NS.Preview.IsActive() == true then return not st.testDismissed end
    return NS.GetSetting("bar.shown") == true
end

--- @return boolean the bar is dismissed for the current test session
function Bar.TestDismissed() return st.testDismissed end

--- The player's show or hide while test mode is on (see the header): dismiss the bar for this test
--- session, or bring it back, without writing `bar.shown` and without ending test mode. Outside test
--- mode it does nothing and answers false, so the caller writes `bar.shown` as usual.
--- @param want boolean
--- @return boolean taken  test mode took the request
function Bar.SetTestShown(want)
    if NS.Preview.IsActive() ~= true then return false end
    st.testDismissed = not want
    Bar.Refresh()
    return true
end

--- The header's close X: dismissed for the test session in test mode, else `bar.shown` off.
function Bar.Close()
    if not Bar.SetTestShown(false) then NS.SetByPath("bar.shown", false) end
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
    bar = f
    Bar.BuildChrome(f)
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", "OutfitterRebornBarRow" .. i, f)
        row:SetFrameLevel(level(f) + LAYERS.LEVEL.BAR_ROW)
        row:Hide()
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetWordWrap(false)
        rows[i] = { frame = row, pool = NS.Pool.New(), label = label }
    end
    return f
end

--- The container, or nil before the first render (for the suites and the skin survey).
function Bar.Frame() return bar end

--- Row `i`'s category label (a FontString), or nil before the first render.
--- @param i number
--- @return table|nil
function Bar.Label(i) return rows[i] and rows[i].label end

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

--- Row `row`'s category label over block `b` (truncated to its width), justified to the side the
--- bar grows from; hidden with the labels off.
local function placeLabel(row, b, spec, categoryID)
    local fs = row.label
    if spec.labelH <= 0 then return fs:Hide() end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", bar, "TOPLEFT", b.label.x, -b.label.y)
    fs:SetWidth(b.label.w)
    fs:SetHeight(spec.labelH)
    fs:SetJustifyH(spec.gx > 0 and "LEFT" or "RIGHT")
    Bar.StyleLabel(fs, NS.WindowListModel.LABEL[categoryID] or tostring(categoryID))
    fs:Show()
end

--- Place row frame `row` at layout block `b` and fill it with `outfits`, `size` px buttons at the
--- block's points (anchored to the bar's TOPLEFT, Bar_Layout's coordinates).
local function placeRow(row, b, outfits, size, style)
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
        Bar.SetButton(btn, rec, style)
    end
end

--- The rows a source answers, without the empty ones, at most one per row frame; while the bar is
--- Collapsed, one row of them all, in display order (no label draws for it).
local function shownRows(source)
    local out = {}
    for _, row in ipairs(source.Rows() or {}) do
        if #out < MAX_ROWS and type(row.outfits) == "table" and #row.outfits > 0 then out[#out + 1] = row end
    end
    if #out < 2 or not Bar.Collapsed() then return out end
    local all = {}
    for _, row in ipairs(out) do
        for _, rec in ipairs(row.outfits) do all[#all + 1] = rec end
    end
    return { { categoryID = out[1].categoryID, outfits = all } }
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
    local style = Bar.IconStyle()
    for i, row in ipairs(list) do
        placeRow(rows[i], g.blocks[i], row.outfits, spec.size, style)
        placeLabel(rows[i], g.blocks[i], spec, row.categoryID)
    end
    bar:SetSize(g.width, g.height)
    bar:SetScale(scale())
    anchor(placed())
    Bar.PaintChrome(bar)
    if t0 then Perf.Note("barRender", debugprofilestop() - t0) end
end

local function hideFrames()
    if not bar then return end
    NS.CloseMenuFrom(Bar.IsButton)
    fadeStop(bar)
    bar:Hide()
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
    -- The strip first, so the rows make room only for one that is drawn (none without the library,
    -- where the header's title carries the test-mode word instead).
    ensureFrame()
    local strip = preview and Bar.EnsureStrip() or nil
    Bar.Render(preview and NS.Preview.Source or Bar.LiveSource, strip ~= nil)
    if strip then strip:Show() elseif bar.strip then bar.strip:Hide() end
    Bar.SetTitle(preview and strip == nil)
    bar:Show()
    Bar.SetLocked(locked())
    Bar.ApplyAlpha()
    if Bar.CornerDisagrees() then Bar.SavePosition() end
    return true
end

--- Whether the saved corner is not the one an explicit grow direction implies: a place written while
--- the bar was hidden, a Reset position or a profile switch. The bar then grows from the wrong edge
--- until it is re-saved, which Refresh does from where it was just drawn (so it does not move). A
--- rect the client has not laid yet is left for the next draw.
--- @return boolean
function Bar.CornerDisagrees()
    if not bar or bar:GetLeft() == nil or testPlace() then return false end
    local q = QUADRANT[position().point]
    local gx, gy = GROW_X[NS.GetSetting("bar.layout.growH")], GROW_Y[NS.GetSetting("bar.layout.growV")]
    return (gx ~= nil and gx ~= q[1]) or (gy ~= nil and gy ~= q[2])
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
    anchor(placed())
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

--- The lock as the header's control draws it (the drag strip reads the setting itself).
--- @param on boolean|nil  the lock; nil reads the setting
function Bar.SetLocked(on)
    if on == nil then on = locked() end
    Bar.SetLockIcon(on)
end

--- The pointer is over the bar, a button or a header control: full alpha, the fade stopped.
function Bar.HoverIn()
    if not bar then return end
    st.hovered = true
    fadeStop(bar)
    Bar.ApplyAlpha()
end

--- The pointer left: the bar fades down to its alpha over 0.5 s.
function Bar.HoverOut()
    if not bar then return end
    st.hovered = false
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
    -- A drag in test mode ends the session's place: the bar is where the player put it, and saved.
    if NS.Preview.IsActive() == true then st.testPlace = false end
    if st.active then Bar.Refresh() end
    return NS.db.profile.windows.bar
end

-- ── receivers ─────────────────────────────────────────────────────────────────────────────────

local function onSettings(_, path)
    if type(path) ~= "string" then return end
    -- A new grow direction keeps the bar where it is: its place, re-saved at the corner it implies.
    if GROW[path] and bar and bar:IsShown() and not testPlace() then Bar.SavePosition() end
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

-- A test session starts or ends: either way the session's dismissal and place are over (see the header).
local function onPreviewChanged()
    st.testDismissed, st.testPlace = false, nil
    schedule()
end

local REBUILD = { "OUTFIT_WORN", "OUTFIT_REMOVED", "OUTFIT_ADDED", "OUTFIT_DELETED", "OUTFIT_EDITED",
                  "OUTFIT_RENAMED", "PROFILE_CHANGED" }
local GAME_EVENTS = { "PET_BATTLE_OPENING_START", "PET_BATTLE_OVER" }

local function ensureListeners()
    if mod then return end
    mod = NS.NewBusTarget()
    LibStub("AceTimer-3.0"):Embed(mod)
    for _, key in ipairs(REBUILD) do mod:RegisterMessage(NS.MSG[key], schedule) end
    mod:RegisterMessage(NS.MSG.PREVIEW_CHANGED, onPreviewChanged)
    mod:RegisterMessage(NS.MSG.SETTINGS_CHANGED, onSettings)
    mod:RegisterMessage(NS.MSG.PLAYER_STATE_CHANGED, onPlayerState)
    NS.Skin.OnLooksChanged(schedule)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

--- The stand-down (design §5.12): the pet-battle events and the pending rebuild go, and the bar hides.
function Bar.Suspend()
    st.active, st.hovered, st.testDismissed, st.testPlace = false, false, false, nil
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
