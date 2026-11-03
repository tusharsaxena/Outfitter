local _, NS = ...
-- modules/IconChooser.lua — NS.IconChooser: the outfit icon picker (design §7.8, INV §7.6).
--
-- Open(id, opener) from the menu's Change icon... A POPUP-tier panel (C.LAYERS), clamped, closed by
-- Escape (UISpecialFrames) and by Close(reason): a press outside it (GLOBAL_MOUSE_DOWN, watched only
-- while it is shown; a press on the chooser, its search box or its set dropdown, and the one press that
-- answers the dropdown's open menu, are its own), the window or the sheet closing
-- (modules/Dock.lua calls Close("opener")), its opener's surface hiding (the window or the bar, not
-- the pooled control a redraw hides and re-shows), and the stand-down.
--
-- THE SETS. Recommended (the wildcard, the outfit's item icons, every trigger's icon), Equipped and
-- bags (the inventory cache's items), Item icons and Ability icons (Compat.MacroIcons), and All. The
-- spellbook set is retired. The search filters the two NAMED sets by item or trigger name and is
-- disabled, with a tooltip, on the three fileID-only ones (O33).
--
-- THE GRID is 6 x 5 buttons from NS.Pool, each a cropped square icon with the skin's edge (the icon
-- rule), the pick drawn as a selected list row, and a slider over the rows.
--
-- THE WRITE. OK (or Enter in the search box) writes the pick; Cancel discards it. The wildcard 134400
-- means "Outfitter chooses" and stores nil (the `outfit.icon` row turns it to nil). A native outfit's
-- icon is the `outfit.icon` instance row (NS.SetByPath with the id); an Equipment Manager outfit's is
-- its set's, which the mirror reads, so it goes to NS.EM.SetIcon (P4.10 handback).
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Get/Items/IsEM, NS.EM.SetIcon, NS.Triggers.All,
-- NS.Inventory.Cache, NS.Compat.ItemIcon/MacroIcons.

local IC = {}
NS.IconChooser = IC

local L = NS.L
local C = NS.Constants
local S = NS.Skin

local WILDCARD = 134400
local COLS, ROWS, CELL = 6, 5, 36
local WIDTH, HEIGHT = 300, 340
local NAMED = { recommended = true, equipped = true }
local SETS = { "recommended", "equipped", "item", "ability", "all" }

local frame
local st = { set = "recommended", filter = "", offset = 0, entries = {}, shown = {} }

-- ── the sets ──────────────────────────────────────────────────────────────────────────────────

local function adder(out)
    local seen = {}
    return function(icon, name)
        if type(icon) ~= "number" or seen[icon] then return end
        seen[icon] = true
        out[#out + 1] = { icon = icon, name = name }
    end
end

local function recommended(add, rec)
    add(WILDCARD, L["Outfitter chooses"])
    for _, item in pairs(NS.Outfits.Items(rec)) do
        if item.id and item.id ~= 0 then add(NS.Compat.ItemIcon(item.id), item.name) end
    end
    for _, d in ipairs(NS.Triggers.All()) do add(d.icon, d.name) end
end

local function equipped(add)
    for _, info in ipairs(NS.Inventory.Cache().all or {}) do add(NS.Compat.ItemIcon(info.id), info.name) end
end

local function fileIDs(add, kind)
    for _, icon in ipairs(NS.Compat.MacroIcons(kind)) do add(icon) end
end

local BUILDERS = {
    recommended = function(add, rec) recommended(add, rec) end,
    equipped    = function(add) equipped(add) end,
    item        = function(add) fileIDs(add, "item") end,
    ability     = function(add) fileIDs(add, "ability") end,
    all         = function(add, rec)
        recommended(add, rec); equipped(add); fileIDs(add, "item"); fileIDs(add, "ability")
    end,
}

local function setLabels()
    return { recommended = L["Recommended"], equipped = L["Equipped and bags"], item = L["Item icons"],
             ability = L["Ability icons"], all = L["All"] }
end

-- The set's entries, through the filter when the set is a named one.
local function filtered()
    local needle = NAMED[st.set] and st.filter:lower() or ""
    if needle == "" then return st.entries end
    local out = {}
    for _, e in ipairs(st.entries) do
        if e.name and tostring(e.name):lower():find(needle, 1, true) then out[#out + 1] = e end
    end
    return out
end

-- ── the grid ──────────────────────────────────────────────────────────────────────────────────

local function maxOffset()
    return math.max(0, math.ceil(#st.shown / COLS) - ROWS)
end

local function paint()
    if not frame then return end
    for i, b in ipairs(frame.buttons) do
        local e = st.shown[st.offset * COLS + i]
        b.entry = e
        b.icon:SetTexture(e and e.icon or nil)
        b:SetShown(e ~= nil)
        S.ListRow(b, (e and e.icon == st.pick) and "selected" or "normal")
    end
    frame.scroll:SetMinMaxValues(0, maxOffset())
end

local function refresh()
    st.shown = filtered()
    st.offset = math.min(st.offset, maxOffset())
    paint()
end

--- Show set `key` ("recommended", "equipped", "item", "ability", "all").
function IC.SetSet(key)
    if not BUILDERS[key] or not st.id then return false end
    st.set, st.offset, st.entries = key, 0, {}
    BUILDERS[key](adder(st.entries), NS.Outfits.Get(st.id) or {})
    if frame.set then frame.set:SelectValue(key) end
    local box = frame.search
    if box then
        box:SetEnabled(NAMED[key] == true)
        box:EnableMouse(true)
    end
    refresh()
    return true
end

--- Filter the named sets by `text`.
function IC.SetFilter(text)
    st.filter = tostring(text or "")
    refresh()
end

--- The entries the grid shows, filtered: `{ icon, name? }`.
function IC.Entries() return st.shown end

--- Pick `icon` (not yet written).
function IC.Pick(icon)
    st.pick = icon
    paint()
end

function IC.Selected() return st.pick end

-- ── write and close ───────────────────────────────────────────────────────────────────────────

--- OK: write the pick and close.
--- @return boolean
function IC.Accept()
    local id, icon = st.id, st.pick
    if not id or NS.IsStoodDown() then return false end
    local rec = NS.Outfits.Get(id)
    if rec and icon then
        if NS.Outfits.IsEM(id) then
            NS.EM.SetIcon(rec, icon ~= WILDCARD and icon or nil)
        else
            NS.SetByPath("outfit.icon", icon, id)
        end
    end
    IC.Close("ok")
    return true
end

--- Close without writing.
function IC.Close(reason)
    st.lastClose = reason
    if frame and frame:IsShown() then frame:Hide() end
end

function IC.IsOpen() return frame ~= nil and frame:IsShown() == true end

-- A press outside the chooser. While the set dropdown's menu is open, a press anywhere but on the
-- dropdown belongs to that menu (a pick, or the press that dismisses it) and the menu is then closed;
-- a press on the dropdown is its own toggle, which the OnClick hook below follows.
local function onMouseDown()
    if st.menuOpen and not (frame.set and frame.set:IsMouseOver()) then
        st.menuOpen = false
        return
    end
    for _, part in ipairs({ frame, frame.set, frame.search }) do
        if part and part:IsMouseOver() then return end
    end
    IC.Close("outside")
end

-- ── the frame ─────────────────────────────────────────────────────────────────────────────────

local function newButton(parent, i)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CELL - 2, CELL - 2)
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", col * CELL, -row * CELL)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    S.SquareIcon(b, { crop = true })
    S.IconBorder(b.icon, { fromSkin = true })
    b:SetScript("OnClick", function(self) if self.entry then IC.Pick(self.entry.icon) end end)
    return b
end

local function grid(f)
    f.grid = CreateFrame("Frame", nil, f)
    f.grid:SetSize(COLS * CELL, ROWS * CELL)
    f.grid:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -64)
    f.grid:EnableMouseWheel(true)
    f.grid:SetScript("OnMouseWheel", function(_, delta) f.scroll:SetValue(st.offset - NS.SafeNumber(delta, 0)) end)
    local pool = NS.Pool.New()
    f.buttons = {}
    for i = 1, COLS * ROWS do
        f.buttons[i] = NS.Pool.Acquire(pool, function() return newButton(f.grid, i) end)
    end
    f.scroll = CreateFrame("Slider", "OutfitterRebornIconChooserScroll", f)
    f.scroll:SetOrientation("VERTICAL")
    f.scroll:SetSize(12, ROWS * CELL)
    f.scroll:SetPoint("TOPLEFT", f.grid, "TOPRIGHT", 4, 0)
    f.scroll:SetValueStep(1)
    local track, thumb = f.scroll:CreateTexture(nil, "BACKGROUND"), f.scroll:CreateTexture(nil, "OVERLAY")
    track:SetAllPoints(f.scroll)
    thumb:SetSize(12, 24)
    f.scroll:SetThumbTexture(thumb)
    S.ScrollBar(f.scroll, { track = track, thumb = thumb })
    f.scroll:SetScript("OnValueChanged", function(_, v)
        st.offset = math.max(0, math.min(maxOffset(), math.floor(NS.SafeNumber(v, 0) + 0.5)))
        paint()
    end)
end

local function setPicker(f)
    f.set = NS.MakeDropdown(f, 120)
    if not f.set then return end
    f.set:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
    local labels, opts = setLabels(), {}
    for i, key in ipairs(SETS) do opts[i] = { value = key, label = labels[key] } end
    f.set:SetOptions(opts)
    f.set.onSelect = function(v) st.menuOpen = false; IC.SetSet(v) end
    -- The library's OnClick toggles the menu: a click on a closed one opens it, on an open one closes it.
    f.set:HookScript("OnClick", function() st.menuOpen = not st.menuOpen end)
end

local function searchBox(f)
    f.search = NS.MakeSearchBox(f, 140, { hint = L["Filter by item name"], onChange = function(text) IC.SetFilter(text) end })
    if not f.search then return end
    f.search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -34)
    f.search:HookScript("OnEnterPressed", function() IC.Accept() end)
    f.search:HookScript("OnEnter", function(self)
        if self:IsEnabled() then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["The search works on the named sets only."])
        GameTooltip:Show()
    end)
    f.search:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function footer(f)
    f.ok = NS.Dialogs.Button(f, 80, 22, L["OK"], { primary = true })
    f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    f.ok:SetScript("OnClick", function() IC.Accept() end)
    f.cancel = NS.Dialogs.Button(f, 80, 22, L["Cancel"])
    f.cancel:SetPoint("RIGHT", f.ok, "LEFT", -6, 0)
    f.cancel:SetScript("OnClick", function() IC.Close("cancel") end)
end

local function build()
    if frame then return frame end
    local f = CreateFrame("Frame", "OutfitterRebornIconChooser", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata(C.LAYERS.STRATA.POPUP)
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:Hide()
    S.Panel(f, { popup = true })
    f.title = NS.Dialogs.Label(f, "", "heading")
    f.title:SetPoint("TOP", f, "TOP", 0, -10)
    frame = f
    setPicker(f)
    searchBox(f)
    grid(f)
    footer(f)
    f:SetScript("OnEvent", function(_, event) if event == "GLOBAL_MOUSE_DOWN" then onMouseDown() end end)
    f:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
    f:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        NS.CloseMenu()
        st.id, st.pick, st.opener, st.menuOpen = nil, nil, nil, false
    end)
    table.insert(UISpecialFrames, "OutfitterRebornIconChooser")
    return f
end

-- The surface `opener` sits on: its outermost ancestor below UIParent. The opener itself is a pooled
-- control (a list row's menu mark, a bar button) that every redraw hides and shows again; the surface
-- (the window, the bar) hides only when it really closes (design §7.8 "the opener hiding").
local function hostOf(opener)
    local f = opener
    for _ = 1, 32 do
        local p = type(f.GetParent) == "function" and f:GetParent() or nil
        if type(p) ~= "table" or p == f or p == UIParent then return f end
        f = p
    end
    return f
end

-- The opener's surface hiding closes the chooser it opened; hooked once per surface. Answers the
-- surface watched, or nil.
local function watchOpener(opener)
    if type(opener) ~= "table" then return nil end
    local host = hostOf(opener)
    if type(host.HookScript) ~= "function" then return nil end
    if not host.__ofIconWatch then
        host.__ofIconWatch = true
        host:HookScript("OnHide", function(self) if st.opener == self then IC.Close("opener") end end)
    end
    return host
end

--- Open the chooser on outfit `id`, anchored to `opener`.
--- @return boolean opened
function IC.Open(id, opener)
    local rec = NS.Outfits.Get(id)
    if NS.IsStoodDown() or not rec then return false end
    build()
    if frame:IsShown() then frame:Hide() end
    st.id, st.filter = id, ""
    st.pick = rec.icon or WILDCARD
    frame.title:SetText(L["Choose an icon for %s"]:format(tostring(rec.name or "")))
    if frame.search then frame.search:SetText("") end
    st.opener = watchOpener(opener)
    IC.SetSet("recommended")
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:Show()
    return true
end

--- The frame, built on first use.
function IC.Frame() return build() end

--- Stand-down: closed, its press watch with it.
function IC.Suspend() IC.Close("standdown") end

--- Stand-up: nothing to restore; the chooser opens on a click.
function IC.Resume() end
