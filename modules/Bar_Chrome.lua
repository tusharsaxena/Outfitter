local _, NS = ...
-- modules/Bar_Chrome.lua — the outfit bar's window look (smoke round 2 design G6, D8): the Ka0s
-- window chrome, the header on its title band, the background and border the player can pick, the
-- test strip under the band, and the category labels. Extends NS.Bar (modules/Bar.lua), which calls Bar.BuildChrome once
-- and Bar.PaintChrome on every render.
--
-- TWO SIBLING LAYERS, never one repainted. `bar.chrome` wears NS.ApplySkin's Shell, exactly a Ka0s
-- window (its background, edge and title band), and shows while `bar.bgFromSkin` is on. `bar.plate`
-- is the host's own backdrop, the Background color (or the class color) under the Border block's
-- edge, and shows while it is off. S.Shell records and replays its paint on every skin switch, so a
-- player color painted onto the Shell frame would be overwritten: the two layers switch on
-- visibility instead, and Show background off hides both (DpsRace's race HUD is the model:
-- DpsRace@2e27c30 modules/Hud.lua:446-475).
--
-- THE HEADER stands on the chrome's title band: LibKa0s's S.Band, laid by Shell at the skin's inset
-- and `title.height` (flush and 25 px under EllesmereUI, NS.SkinBandGeometry), or a host holder 1 px
-- in when the library is absent (DpsRace modules/Style.lua:559-575 bandOf). The title,
-- L["Outfits"], is LEFT; the controls are RIGHT, outermost first: close (NS.MakeCloseButton, which
-- writes `bar.shown = false`) and lock (the Master `locked` row, through the one seam). Both are
-- 18 px slots with the close X's art size, painted as the X is (S.CloseButton), as the window's
-- gear is (modules/Window.lua). The drag strip covers the band left of the controls: it moves the
-- bar unless locked, saves the place on release, and a right click opens the bar's settings page.
-- The separate drag handle above the bar is retired.
--
-- THE TEST STRIP hangs flush under the band (DpsRace modules/Hud.lua:501-512), and Bar.HeaderHeight
-- adds its height above the icons.
--
-- THE LABELS (one per category, over its row) are HUD text (skinning-§6): face, size, flags and
-- shadow through S.HudFont from the Labels tab's font block, the size through S.HudFontSize and the
-- flags From skin by default (S.FontFlags inside S.HudFont); the color is the class color, else the
-- skin's HUD label color (S.HudLabelColor) while *Use the skin's color* is on, else the swatch. A
-- skin change re-renders the bar (modules/Bar.lua), which draws them again.
--
-- CALLS (at call time): NS.Skin (Shell through NS.ApplySkin, Band, Header, CloseButton, BarBorder,
-- Resolve, Color, HudFont, HudFontSize, HudLabelColor), NS.SkinBandGeometry, NS.ResolveColor, NS.MakeCloseButton, NS.MakeTestStrip,
-- NS.SetByPath, NS.OpenOptionsPanel.

local Bar = NS.Bar

local L = NS.L
local LAYERS = NS.Constants.LAYERS

local CONTROL, CONTROL_PITCH, CONTROL_PAD = 18, 22, 6   -- DpsRace Style: 18 px slots, 22 apart, 6 in
local ART_FALLBACK = 12                                 -- the close X's art size, when it cannot say
local TITLE_H_FALLBACK = 30                             -- Ka0s Default's title.height
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SOLID = "Solid"

Bar.CONTROL = CONTROL

local function num(v, fallback) return NS.Secrets.UnsecretNumber(v, fallback) end
local function setting(path) return NS.GetSetting(path) end
local function locked() return setting("locked") == true end

-- ── the band ──────────────────────────────────────────────────────────────────────────────────

--- Where the band stands now: its inset from the bar's top and its height. The library's rule while
--- it is loaded (NS.SkinBandGeometry), else the host holder's: 1 in and `title.height` high.
--- @return number inset, number height
function Bar.BandGeometry()
    if NS.SkinBandGeometry then return NS.SkinBandGeometry() end
    return 1, num(NS.Skin.Token("title.height"), TITLE_H_FALLBACK)
end

--- The height above the icons: the header band, and the test strip under it while it shows.
--- @param strip boolean|nil
--- @return number
function Bar.HeaderHeight(strip)
    local inset, h = Bar.BandGeometry()
    local top = inset + h
    if strip then top = top + NS.TEST_STRIP_HEIGHT end
    return top
end

--- The bar's title band: the library's (S.Band on the chrome), else the host's holder. Answers it and
--- whether it is the library's.
local function bandOf(f)
    local band = NS.Skin.Band(f.chrome)
    if band then return band, true end
    if not f.hostBand then
        local _, h = Bar.BandGeometry()
        local b = CreateFrame("Frame", nil, f)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
        b:SetHeight(h)
        b:EnableMouse(false)
        f.hostBand = b
    end
    return f.hostBand, false
end

--- The band the header and the strip stand on, for the suites.
--- @return table|nil
function Bar.Band()
    local f = Bar.Frame()
    return f and (bandOf(f)) or nil
end

-- ── the controls ──────────────────────────────────────────────────────────────────────────────

local function artSize(close)
    local icon = close and rawget(close, "icon")
    local w = type(icon) == "table" and type(icon.GetWidth) == "function" and num(icon:GetWidth(), 0) or 0
    if w <= 0 then return ART_FALLBACK end
    return w
end

local function tooltip(owner, title, body)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title)
    if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
    GameTooltip:Show()
end

local function hideTooltip() if GameTooltip then GameTooltip:Hide() end end

--- The lock control: the Master `locked` row, flipped through the one write seam.
local function lockControl(parent, art)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CONTROL, CONTROL)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.icon:SetSize(art, art)
    NS.Skin.CloseButton(b)
    b:SetScript("OnClick", function() NS.SetByPath("locked", not locked()) end)
    b:HookScript("OnEnter", function(self)
        Bar.HoverIn()
        tooltip(self, L["Lock or unlock the outfit bar"], L["The same switch as Lock frame on General > Master controls."])
    end)
    b:HookScript("OnLeave", function()
        hideTooltip()
        Bar.HoverOut()
    end)
    return b
end

--- The drag strip: drag to move (refused while locked), right-click for the bar's settings.
local function dragStrip(f, parent)
    local d = CreateFrame("Frame", nil, parent)
    d:EnableMouse(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", function() if not locked() then f:StartMoving() end end)
    d:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        Bar.SavePosition()
    end)
    d:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then NS.OpenOptionsPanel("bar") end
    end)
    d:SetScript("OnEnter", function(self)
        Bar.HoverIn()
        tooltip(self, L["Outfit bar"], L["Drag to move. Right-click for bar settings."])
    end)
    d:SetScript("OnLeave", function()
        hideTooltip()
        Bar.HoverOut()
    end)
    return d
end

--- Lay the title, the controls and the drag strip on the band: S.Header while the library lays the
--- band (recorded, so a skin switch lays them again), else the same anchors set once by hand.
local function placeHeader(f)
    local band, fromLib = bandOf(f)
    local right, n = {}, 0
    for _, b in ipairs({ f.close or false, f.lock }) do
        n = n + 1
        if b then
            local x = CONTROL_PAD + (n - 1) * CONTROL_PITCH
            right[#right + 1] = { frame = b, width = CONTROL, x = x }
            if not fromLib then
                b:ClearAllPoints()
                b:SetPoint("RIGHT", band, "RIGHT", -x, 0)
            end
        end
    end
    local reach = CONTROL_PAD + (n - 1) * CONTROL_PITCH + CONTROL + 2
    f.drag:ClearAllPoints()
    f.drag:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
    f.drag:SetPoint("BOTTOMRIGHT", band, "BOTTOMRIGHT", -reach, 0)
    if fromLib then
        NS.Skin.Header(f.chrome, { title = f.title, align = "LEFT", right = right })
        return
    end
    f.title:ClearAllPoints()
    f.title:SetPoint("LEFT", band, "LEFT", 8, 0)
    f.title:SetPoint("RIGHT", f.drag, "RIGHT", -4, 0)
    f.title:SetJustifyH("LEFT")
end

-- ── build ─────────────────────────────────────────────────────────────────────────────────────

--- The chrome, the plate and the header on container `f`, once (modules/Bar.lua's ensureFrame).
--- @param f table the bar
function Bar.BuildChrome(f)
    local base = num(f:GetFrameLevel(), 0)
    f.chrome = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.chrome:SetAllPoints(f)
    f.plate = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.plate:SetAllPoints(f)
    f.plate:Hide()
    local header = CreateFrame("Frame", nil, f)
    header:SetAllPoints(f)
    header:SetFrameLevel(base + LAYERS.LEVEL.HANDLE)
    f.header = header
    f.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetText(L["Outfits"])
    -- Shell paints `frame.title` in the skin's title face and color.
    f.chrome.title = f.title
    NS.ApplySkin(f.chrome)
    f.close = NS.MakeCloseButton(header, function() NS.SetByPath("bar.shown", false) end)
    f.lock = lockControl(header, artSize(f.close))
    f.drag = dragStrip(f, header)
    placeHeader(f)
    Bar.SetLockIcon(locked())
end

--- The lock control's art: closed while the Master lock is on.
--- @param on boolean
function Bar.SetLockIcon(on)
    local f = Bar.Frame()
    if not (f and f.lock) then return end
    f.lock.icon:SetTexture(NS.Icon(on and "lock" or "unlock"))
end

--- The test strip, built the first time test mode shows the bar, flush under the band.
--- @return table|nil
function Bar.EnsureStrip()
    local f = Bar.Frame()
    if f.strip == nil then
        local strip = NS.MakeTestStrip(f, L["Test mode: sample outfits. Nothing is equipped or saved"])
        f.strip = strip or false
        if strip then
            local band = bandOf(f)
            strip:SetFrameLevel(num(f:GetFrameLevel(), 0) + LAYERS.LEVEL.MARKER)
            strip:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
            strip:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
        end
    end
    return f.strip or nil
end

-- ── the labels ────────────────────────────────────────────────────────────────────────────────

local LABEL = "bar.labels."
local LABEL_LEADING = 4   -- the label line's height over its drawn size

--- Whether the category labels show.
--- @return boolean
function Bar.LabelsShown() return setting(LABEL .. "show") ~= false end

local function labelFromSkin() return setting(LABEL .. "fontFromSkin") ~= false end

local function labelSize()
    return NS.Skin.HudFontSize(setting(LABEL .. "fontSize"), labelFromSkin())
end

--- The label line's height (0 with the labels off), from the size the label draws at.
--- @return number
function Bar.LabelHeight()
    if not Bar.LabelsShown() then return 0 end
    return math.ceil(num(labelSize(), 11)) + LABEL_LEADING
end

--- The stored face's path while the labels keep their own face; nil follows the skin (S.HudFont).
local function labelFace()
    if labelFromSkin() then return nil end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    return LSM and LSM.Fetch and LSM:Fetch("font", setting(LABEL .. "font"), true) or nil
end

--- The label color: the class color, else the skin's HUD label color while it follows the skin,
--- else the swatch.
local function labelColor()
    local class = setting(LABEL .. "useClassColorFont") == true
    if not class and setting(LABEL .. "fontColorFromSkin") ~= false then
        local r, g, b, a = NS.Skin.HudLabelColor()
        if r ~= nil then return r, g, b, a or 1 end
    end
    return NS.ResolveColor(setting(LABEL .. "fontColor"), class)
end

--- Draw `text` on label `fs` in the Labels tab's look.
--- @param fs table a FontString
--- @param text string
function Bar.StyleLabel(fs, text)
    NS.Skin.HudFont(fs, {
        face = labelFace(), size = labelSize(), flags = setting(LABEL .. "fontFlags"),
        shadow = setting(LABEL .. "fontShadow") == true,
        shadowFromSkin = setting(LABEL .. "fontShadowFromSkin") ~= false,
    })
    fs:SetTextColor(labelColor())
    fs:SetText(text)
end

-- ── the background and the border ─────────────────────────────────────────────────────────────

do
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    -- The flat edge, under AuraMaster's and Drop Watcher's name (the first registration wins).
    if LSM and LSM.Register then LSM:Register("border", SOLID, WHITE) end
end

--- A border style's texture: LibSharedMedia's, else the flat edge for Solid; nil for None.
--- @param style string|nil
--- @return string|nil
function Bar.BorderFile(style)
    if style == nil or style == "None" then return nil end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local path = LSM and LSM.Fetch and LSM:Fetch("border", style, true)
    return path or WHITE
end

--- A border color as drawn: the class color, else the skin's `token` while `fromSkin`, else the
--- stored swatch (NS.ResolveColor's ladder with the skin's rung).
--- @return number r, number g, number b, number a
function Bar.EdgeColor(prefix, token)
    local stored = setting(prefix .. "borderColor")
    local class = setting(prefix .. "useClassColorBorder") == true
    if not class and setting(prefix .. "borderColorFromSkin") == true then
        local r, g, b, a = NS.Skin.Color(token)
        if r ~= nil then return r, g, b, a or 1 end
    end
    return NS.ResolveColor(stored, class)
end

--- The Border block under `prefix` as drawn: show, style and thickness, the skin's bar family while
--- its companion is on (S.BarBorder, so a skin's None leaves them to the player).
--- @return boolean show, string|nil style, number size
local function frameBorder(prefix)
    local fromSkin = setting(prefix .. "borderStyleFromSkin") == true
    local style, show, size = NS.Skin.BarBorder(setting(prefix .. "borderStyle"), setting(prefix .. "borderShow"),
        setting(prefix .. "borderSize"), fromSkin)
    return show ~= false and style ~= nil and style ~= "None", style, math.max(num(size, 1), 1)
end

--- The plate: the Background color (or the class color) under the Border block's edge.
local function paintPlate(plate)
    local show, style, size = frameBorder("bar.frame.")
    local edge = show and Bar.BorderFile(style) or nil
    local inset = edge and size or 0
    plate:SetBackdrop({ bgFile = WHITE, edgeFile = edge, edgeSize = edge and size or nil,
        insets = { left = inset, right = inset, top = inset, bottom = inset } })
    plate:SetBackdropColor(NS.ResolveColor(setting("bar.bgColor"), setting("bar.useClassColorBg") == true))
    if edge then plate:SetBackdropBorderColor(Bar.EdgeColor("bar.frame.", "bar.border")) end
end

--- Show the one background layer the settings ask for and paint the plate when it is that one.
--- @param f table the bar
function Bar.PaintChrome(f)
    local shown = setting("bar.showBackground") ~= false
    local skin = setting("bar.bgFromSkin") ~= false
    f.chrome:SetShown(shown and skin)
    f.plate:SetShown(shown and not skin)
    if shown and not skin then paintPlate(f.plate) end
end
