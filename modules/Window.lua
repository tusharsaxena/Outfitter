local _, NS = ...
-- modules/Window.lua — NS.Window: the outfit window's chrome, the list body, the scroll bar and the
-- footer, and its render (design §7.1, §7.3, INV §7.1-§7.2).
--
-- `OutfitterRebornWindow` is built once, by modules/Dock.lua, which owns every Show and Hide of it,
-- its position and its layers. This file draws what is in it. No tabs: the old Options and About
-- panels are the settings pages and their landing page. No scale of its own: it inherits UIParent's.
--
-- DIRTY, THEN DRAWN. Window.MarkDirty(wipeCache) replaces the old Update(true): the bus receivers
-- below mark the list dirty (and wipe the outfit status cache), and the dock's follow tick draws it
-- while the window is shown (Window.RenderIfDirty). Nothing renders while the window is hidden.
--
-- TEST MODE (smoke round 2 design G7). Win.SetTestMode, called by Dock.Refresh before every show and
-- so never in lockdown, puts the amber strip (NS.MakeTestStrip, the bar's own) under the title divider,
-- pushes the list down by its height and grows the window to match, and disables New outfit (it would
-- make a real outfit); the Slots buttons stay hidden. One marker per mode: the title says test mode
-- only when the library is degraded and there is no strip.
--
-- CALLS (at call time; design §12): NS.Dock.Close, NS.WindowRows, NS.WindowListModel, NS.Stack.Selected,
-- NS.Outfits.SetAllSlotsEnabled, NS.OutfitDialog.OpenNew, NS.OpenOptionsPanel, NS.Preview.IsActive,
-- NS.MakeTestStrip.

local Win = { collapsed = {}, offset = 0, dirty = true, entries = {}, WIDTH = 260, HEIGHT = 320, inset = 0 }
NS.Window = Win

local L = NS.L
local LEVEL = NS.Constants.LAYERS.LEVEL

local frame, list, scroll, newButton
local chrome = {}          -- the title-strip and footer controls, re-leveled at W + CHROME
local footer = {}          -- the Slots: [All] [None] trio, shown while an outfit is selected
local statusCache = {}
local installed = false

-- Every message that can change a row: each marks the list dirty and wipes the status cache.
-- STACK_CHANGED is not among them: a stack change re-draws the worn marks, and an outfit's missing
-- or banked status is inventory-driven, so it marks the list dirty and keeps the cache (Win.Install).
-- PREVIEW_CHANGED swaps the whole list for the sample outfits and back (smoke round 2 design G7).
local DIRTY_ON = { "OUTFIT_ADDED", "OUTFIT_DELETED", "OUTFIT_EDITED", "OUTFIT_RENAMED", "OUTFIT_WORN",
                   "OUTFIT_REMOVED", "INVENTORY_CHANGED", "SELECTION_CHANGED", "EM_SYNCED",
                   "TRIGGERS_REBOUND", "PREVIEW_CHANGED" }

local function wipe(t) for k in pairs(t) do t[k] = nil end end

--- Mark the list for a redraw; `wipeCache` drops the outfit status cache too.
--- @param wipeCache boolean|nil
function Win.MarkDirty(wipeCache)
    if wipeCache then wipe(statusCache) end
    Win.dirty = true
end

--- @return table|nil the window frame, once built
function Win.Frame() return frame end

local function selectedFooter()
    local on = NS.Stack.Selected() ~= nil and not NS.Preview.IsActive()
    for _, f in ipairs(footer) do f:SetShown(on) end
end

--- Draw the list now (a no-op while the window is hidden).
function Win.Render()
    if not (frame and frame:IsShown()) then return end
    Win.dirty = false
    local entries = NS.WindowListModel.Build(Win.collapsed, statusCache)
    Win.entries = entries
    local Rows = NS.WindowRows
    local maxOffset = math.max(0, #entries - Rows.COUNT)
    if Win.offset > maxOffset then Win.offset = maxOffset end
    scroll:SetMinMaxValues(0, maxOffset)
    scroll:SetValue(Win.offset)
    for i, row in ipairs(Rows.rows) do
        local n = Win.offset + i
        Rows.Bind(row, entries[n], n)
    end
    selectedFooter()
end

--- The dock's follow tick: draw if something marked the list.
function Win.RenderIfDirty()
    if Win.dirty then Win.Render() end
end

--- Scroll to `n` rows down (clamped at render).
--- @param n number
function Win.SetOffset(n)
    n = math.max(0, math.floor(NS.SafeNumber(n, 0)))
    if n == Win.offset and not Win.dirty then return end
    Win.offset = n
    Win.Render()
end

--- Collapse or expand a category for the session.
--- @param id string
function Win.ToggleCollapsed(id)
    Win.collapsed[id] = not Win.collapsed[id] or nil
    Win.MarkDirty(false)
    Win.Render()
end

--- Re-assert the window's stack over `base`, its own level (frame-layering-§3): chrome +CHROME, the
--- body and rows +CONTENT, the scroll bar +SCROLL. After every strata or level change, and after a
--- SetParent.
--- @param base number|nil
function Win.Relevel(base)
    if not frame then return end
    base = NS.SafeNumber(base, nil) or NS.SafeNumber(frame:GetFrameLevel(), 0)
    for _, c in ipairs(chrome) do c:SetFrameLevel(base + LEVEL.CHROME) end
    list:SetFrameLevel(base + LEVEL.CONTENT)
    NS.WindowRows.Relevel(base + LEVEL.CONTENT)
    scroll:SetFrameLevel(base + LEVEL.SCROLL)
end

-- ── test mode ─────────────────────────────────────────────────────────────────────────────────

-- The list's top under the title divider, and the strip's gap below it.
local LIST_TOP, STRIP_TOP, STRIP_GAP = -30, -27, 2

-- The strip, built the first time test mode shows the window; false when the library is degraded.
local function ensureStrip()
    if frame.strip == nil then
        local strip = NS.MakeTestStrip(frame, L["Test mode: sample outfits, nothing equipped"])
        frame.strip = strip or false
        if strip then
            strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 1 + Win.inset, STRIP_TOP)
            strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, STRIP_TOP)
            chrome[#chrome + 1] = strip
            strip:SetFrameLevel(NS.SafeNumber(frame:GetFrameLevel(), 0) + LEVEL.CHROME)
        end
    end
    return frame.strip or nil
end

--- The window's size as this file set it, in its own units: the width and the height with the test
--- strip's push. Read where the client's rect may not be laid yet (the dock's alone spot).
--- @return number width, number height
function Win.Size() return Win.WIDTH + Win.inset, Win.HEIGHT + (Win.push or 0) end

--- Widen the window by `px` on its left and move its contents right by as much (Forever smoke
--- feedback S5): a side-tab strip that hangs over the docked window's left edge then lies over an
--- empty band of the window's own background, and the window is extended, never moved. The dock
--- passes the strip's reach (NS.Sheet.StripInset) on every placing and 0 standing alone. Out of
--- lockdown only (the list holds secure children); a no-op when the inset is unchanged.
--- @param px number
function Win.SetLeftInset(px)
    if not frame then return end
    px = math.floor(math.max(0, NS.SafeNumber(px, 0)) + 0.5)
    if px == Win.inset then return end
    Win.inset = px
    frame:SetWidth(Win.WIDTH + px)
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 + px, -8)
    frame.divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1 + px, -26)
    if frame.strip then frame.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 1 + px, STRIP_TOP) end
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + px, LIST_TOP - (Win.push or 0))
    newButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8 + px, 8)
end

--- Dress the window for test mode or take it off: the strip, the list's push, the height, New outfit
--- and the degraded title. Dock.Refresh only (the list holds secure children: never in lockdown).
--- @param on boolean
function Win.SetTestMode(on)
    if not frame then return end
    on = on == true
    if on == Win.testMode then return end
    Win.testMode = on
    local strip = on and ensureStrip()
    if strip then strip:Show() elseif frame.strip then frame.strip:Hide() end
    local push = strip and (NS.TEST_STRIP_HEIGHT + STRIP_GAP) or 0
    Win.push = push
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + Win.inset, LIST_TOP - push)
    frame:SetHeight(Win.HEIGHT + push)
    frame.title:SetText((on and not strip) and L["Outfitter Reborn (test mode)"] or L["Outfitter Reborn"])
    newButton:SetEnabled(not on)
    selectedFooter()
    Win.MarkDirty(true)
end

-- ── build ─────────────────────────────────────────────────────────────────────────────────────

local function labeledButton(name, parent, w, h, text, opts)
    local b = CreateFrame("Button", name, parent)
    b:SetSize(w, h)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(text)
    NS.Skin.Button(b, opts)
    chrome[#chrome + 1] = b
    return b
end

-- The close X's art size, read off its own art (LibKa0s Core's CLOSE_ART is a file-local), so the
-- gear follows it; 12, that value, when the close draws a font glyph or is not there.
local GEAR_ART_FALLBACK = 12

local function closeArtSize(close)
    local icon = close and rawget(close, "icon")
    local w = type(icon) == "table" and type(icon.GetWidth) == "function" and NS.SafeNumber(icon:GetWidth(), 0) or 0
    if w <= 0 then return GEAR_ART_FALLBACK end
    return w
end

local function titleStrip(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.title:SetText(L["Outfitter Reborn"])
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -26)
    f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -26)
    NS.ApplySkin(f)
    -- NS.MakeCloseButton makes and skins the x but anchors nothing: the caller places it, as
    -- modules/UIDialogs.lua does. Unanchored it never drew (design G10).
    local close = NS.MakeCloseButton(f, function() NS.Dock.Close() end)
    if close then
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -5)
        f.close = close
        chrome[#chrome + 1] = close
    end
    local gear = CreateFrame("Button", "OutfitterRebornWindowSettings", f)
    gear:SetSize(18, 18)
    gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -5)
    -- The art at the close X's art size, centered in the unchanged 18 px click target, and painted as
    -- the X is (close.rest, close.hot under the pointer), so the two header controls read as a pair
    -- (smoke round 2 design G5).
    local art = closeArtSize(close)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetPoint("CENTER", gear, "CENTER", 0, 0)
    gear.icon:SetSize(art, art)
    gear.icon:SetTexture(NS.Icon("settings"))
    NS.Skin.CloseButton(gear)
    gear:SetScript("OnClick", function() if not NS.IsStoodDown() then NS.OpenOptionsPanel() end end)
    chrome[#chrome + 1] = gear
end

local function body(f)
    local Rows = NS.WindowRows
    list = CreateFrame("Frame", "OutfitterRebornWindowList", f)
    list:SetSize(Rows.ROW_W, Rows.COUNT * Rows.ROW_H)
    list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, LIST_TOP)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) Win.SetOffset(Win.offset - NS.SafeNumber(delta, 0)) end)
    Rows.Build(list)
    scroll = CreateFrame("Slider", "OutfitterRebornWindowScroll", f)
    scroll:SetOrientation("VERTICAL")
    scroll:SetSize(12, Rows.COUNT * Rows.ROW_H)
    scroll:SetPoint("TOPLEFT", list, "TOPRIGHT", 4, 0)
    scroll:SetValueStep(1)
    scroll:SetObeyStepOnDrag(true)
    scroll:SetMinMaxValues(0, 0)
    local track, thumb = scroll:CreateTexture(nil, "BACKGROUND"), scroll:CreateTexture(nil, "OVERLAY")
    track:SetAllPoints(scroll)
    thumb:SetSize(12, 24)
    scroll:SetThumbTexture(thumb)
    NS.Skin.ScrollBar(scroll, { track = track, thumb = thumb })
    scroll:SetScript("OnValueChanged", function(_, value) Win.SetOffset(value) end)
end

local function footerRow(f)
    local new = labeledButton("OutfitterRebornNewOutfitButton", f, 120, 20, L["New outfit..."], { primary = true })
    new:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 8)
    new.mark = new:CreateTexture(nil, "ARTWORK")
    new.mark:SetSize(12, 12)
    new.mark:SetPoint("LEFT", new, "LEFT", 4, 0)
    new.mark:SetTexture(NS.Icon("add"))
    NS.Skin.Mark(new.mark)
    new:SetScript("OnClick", function()
        if not NS.IsStoodDown() and not NS.Preview.IsActive() then NS.OutfitDialog.OpenNew() end
    end)
    newButton = new
    local none = labeledButton("OutfitterRebornSlotsNone", f, 40, 18, L["None"])
    none:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 9)
    local all = labeledButton("OutfitterRebornSlotsAll", f, 40, 18, L["All"])
    all:SetPoint("RIGHT", none, "LEFT", -4, 0)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("RIGHT", all, "LEFT", -4, 0)
    label:SetText(L["Slots:"])
    NS.Skin.Text(label, "muted")
    local function setAll(on)
        local sel = NS.Stack.Selected()
        if NS.IsStoodDown() or not sel then return end
        NS.Outfits.SetAllSlotsEnabled(sel, on)
    end
    all:SetScript("OnClick", function() setAll(true) end)
    none:SetScript("OnClick", function() setAll(false) end)
    footer[1], footer[2], footer[3] = label, all, none
    for _, x in ipairs(footer) do x:Hide() end
end

--- Build the window, once. Hidden until the dock shows it; out of combat only (Dock.Refresh).
--- @return table the frame
function Win.Build()
    if frame then return frame end
    local f = CreateFrame("Frame", "OutfitterRebornWindow", UIParent, "BackdropTemplate")
    f:SetSize(Win.WIDTH, Win.HEIGHT)
    f:Hide()
    titleStrip(f)
    body(f)
    footerRow(f)
    frame = f
    return f
end

--- The bus receivers, once per session; the bus record drops and replays them across a stand-down.
--- And the skin's looks-changed listener: an item row's name wears its quality color, NS.QualityColor
--- (the skin's q.* tokens), written at render rather than by a recorded primitive, so a skin switch
--- marks the list for the follow tick's redraw (core/SkinSetup.lua: a surface that draws at render
--- subscribes to NS.Skin.OnLooksChanged).
function Win.Install()
    if installed then return end
    installed = true
    NS.Skin.OnLooksChanged(function() Win.MarkDirty(false) end)
    local bus = NS.NewBusTarget()
    if not bus then return end
    for _, key in ipairs(DIRTY_ON) do
        bus:RegisterMessage(NS.MSG[key], function() Win.MarkDirty(true) end)
    end
    bus:RegisterMessage(NS.MSG.STACK_CHANGED, function() Win.MarkDirty(false) end)
    -- auto.enabled dims the trigger marks; an Outfit Window row (smoke round 3 E11) changes the
    -- sections or the marks the list draws.
    bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path)
        if path == "auto.enabled" or (type(path) == "string" and path:find("^window%.")) then
            Win.MarkDirty(false)
        end
    end)
    -- A profile switch writes no row, so the new profile's auto.enabled and window.* reach the list here.
    bus:RegisterMessage(NS.MSG.PROFILE_CHANGED, function() Win.MarkDirty(false) end)
end
