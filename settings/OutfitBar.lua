local _, NS = ...
-- settings/OutfitBar.lua — the Outfit Bar settings page, `bar` (design §4.2, smoke round 2 design G6),
-- registered between General and Profiles. Tabs: Display (what shows, and the bar's one anchor row,
-- `bar.position`, never drawn), Layout (orientation, wrap, padding, spacing, grow direction), Icons
-- (their size and border), Labels (each category's, a composed font block) and Frame (the background and the
-- border, options-ui-§16's composed blocks).
--
-- NO SECOND SWITCHES (options-ui-§15). Scale, opacity, the lock, Reset position and General
-- visibility are the Master controls' and govern this one frame. The Display tab's Reset position
-- button and the header's lock (modules/Bar_Chrome.lua) write THE SAME paths (`bar.position` through
-- NS.ApplyDefault, `locked` through the seam), and "hide in combat" is General visibility, which
-- the combat opacity row points to.
--
-- FOLLOWING THE SKIN (skinning-§6). Every color here carries a FromSkin companion, default on: the
-- composers' own (`fontFromSkin`, `borderStyleFromSkin`) and, in this addon's words after each block
-- (so never `composed`), *Use the skin's background*, *Use the skin's color* and *Use the skin's
-- shadow*. Font flags lead with From skin (`flagsFromSkin`), drawn through S.FontFlags.
--
-- The bar re-renders on SETTINGS_CHANGED for any `bar.*` path (modules/Bar.lua), so no row here needs
-- an onChange: the panel, `/or set` and a reset all reach the bar the same way.

local L = NS.L
local D = NS.defaults.profile
local PAGE = "bar"
local DISPLAY = L["Display"]
local LAYOUT = L["Layout"]
local ICONS = L["Icons"]
local LABELS = L["Labels"]
local FRAME = L["Frame"]
local DB = D.bar
local H = NS.Helpers
local PLAYER_CLASS = { source = "player" }

-- The rows after a composed block in this addon's words; every other row of a block is the
-- library's, marked `composed` (options-ui-§21).
local function ownWords(path)
    return path:find("bgFromSkin", 1, true) ~= nil or path:find("ColorFromSkin", 1, true) ~= nil
        or path:find("ShadowFromSkin", 1, true) ~= nil
end

--- Register composed `rows`: the library's words marked, the addon's own left as they are.
local function registerComposed(rows)
    for _, r in ipairs(rows) do
        if not ownWords(r.path) then r.composed = true end
    end
    NS.RegisterSchemaRows(rows)
end

--- The *Use the skin's color* row after a Border block.
local function borderColorFollow(prefix, d)
    return { path = prefix .. "borderColorFromSkin", type = "bool", startsLine = true,
             label = L["Use the skin's color"], default = d.borderColorFromSkin,
             tooltip = L["Draw this border in the skin's color. The Border color swatch is not read while this is on, and Use class color comes first."] }
end

-- ── bar.position ────────────────────────────────────────────────────────────────────────────────
-- A string row whose storage is `profile.windows.bar` (`{ point, x, y }`, design §3.4), so the bar's
-- drag stop and `/or get|set|reset bar.position` reach the bar's place through the one write seam (the
-- old `reset bar`, H5). Its default is the defaults tree's, encoded, and every write decodes into a
-- NEW table, so a reset copies the default and never aliases it (the legacy aliased it:
-- OutfitterBar.lua:107-115).
local CORNERS = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

--- A coordinate as text: whole numbers bare, anything else to two places without trailing zeros.
local function coord(n)
    if n == math.floor(n) then return ("%d"):format(n) end
    return (("%.2f"):format(n):gsub("0+$", ""):gsub("%.$", ""))
end

--- `{ point, x, y }` as `POINT X Y`. Published for the bar's drag stop (modules/Bar.lua), which
--- writes the row through NS.SetByPath like every other writer.
local function encode(p) return p.point .. " " .. coord(p.x) .. " " .. coord(p.y) end
NS.EncodeBarPosition = encode

--- A real offset: a number that is neither NaN nor infinite. Lua's tonumber parses "nan", "inf" and
--- "1e400", which no drag can produce and which would anchor the bar off-screen.
local function finite(n)
    -- NaN fails both comparisons, so the one range test refuses it with the infinities.
    return type(n) == "number" and n > -math.huge and n < math.huge
end

--- `POINT X Y` as `{ point, x, y }`, or nil when it is not a corner and two finite numbers.
local function decode(v)
    if type(v) ~= "string" then return nil end
    local point, x, y = v:match("^%s*(%u+)%s+(%S+)%s+(%S+)%s*$")
    x, y = tonumber(x), tonumber(y)
    if not (point and CORNERS[point] and finite(x) and finite(y)) then return nil end
    return { point = point, x = x, y = y }
end

--- The bar's stored place, or the default's while the store cannot answer (before InitDB) or holds
--- no corner (the bar's own fallback) or a non-finite offset (which the row never writes).
local function storedPosition()
    local p = NS.db and NS.db.profile and NS.db.profile.windows and NS.db.profile.windows.bar
    if type(p) == "table" and CORNERS[p.point] and finite(p.x) and finite(p.y) then
        return p
    end
    return D.windows.bar
end

NS.RegisterSchemaRows({
    -- Leads the block (options-ui-§16).
    { path = "bar.shown", page = PAGE, group = DISPLAY, type = "bool",
      label = L["Show outfit bar"], default = DB.shown,
      tooltip = L["Shows a bar of outfit buttons you can click to wear or remove an outfit."] },
    { path = "bar.worn.style", page = PAGE, group = DISPLAY, type = "string",
      values = { mark = L["Corner mark"], border = L["Border"], both = L["Mark and border"], none = L["None"] },
      sorting = { "both", "mark", "border", "none" },
      label = L["Worn outfit highlight"], default = DB.worn.style,
      tooltip = L["How the bar marks an outfit you are wearing: a check mark in its corner, a border in the skin's highlight color, both, or nothing."] },
    { path = "bar.combatAlpha", page = PAGE, group = DISPLAY, type = "number", isPercent = true,
      min = 0, max = 1, step = 0.05, label = L["Opacity in combat (%)"], default = DB.combatAlpha,
      tooltip = L["To hide the bar in combat, set General visibility on General > Master controls. Multiplied by Master opacity on General > Master controls."] },
    -- Never drawn: the header's drag places the bar, and Reset position (here, and on General > Master
    -- controls) resets this row. Its own get/set are its storage.
    { path = "bar.position", page = PAGE, group = DISPLAY, type = "string", skipRender = true,
      label = L["Outfit bar position"], default = encode(D.windows.bar),
      tooltip = L["The outfit bar's screen corner and offset, as POINT X Y (for example TOPLEFT 200 -200)."],
      validate = function(v) return decode(v) ~= nil end,
      get = function() return encode(storedPosition()) end,
      set = function(v) NS.db.profile.windows.bar = decode(v) end },
})

-- ── Layout ─────────────────────────────────────────────────────────────────────────────────────
-- The geometry modules/Bar_Layout.lua computes from. A grow direction other than Automatic pins the
-- corner the bar is saved at (modules/Bar.lua's SavePosition), so a drag never flips its growth.
local GROW_H = { auto = L["Automatic"], right = L["Right"], left = L["Left"] }
local GROW_V = { auto = L["Automatic"], down = L["Down"], up = L["Up"] }
-- Grouped: one block per category under its label; Collapsed: one block, no labels (smoke round 3
-- E9), so every Labels row is hidden while it is picked (options-ui-§22).
local MODES = { grouped = L["Grouped"], collapsed = L["Collapsed"] }

NS.RegisterSchemaRows({
    { path = "bar.layout.mode", page = PAGE, group = LAYOUT, type = "string",
      values = MODES, sorting = { "grouped", "collapsed" },
      label = L["Grouping"], default = DB.layout.mode,
      tooltip = L["Grouped: one row of icons per category (one column in the vertical layout), each under its label. Collapsed: every outfit the bar shows in a single group with no labels, and the Labels tab's rows are hidden."] },
    { path = "bar.vertical", page = PAGE, group = LAYOUT, type = "bool",
      label = L["Vertical layout"], default = DB.vertical,
      tooltip = L["One column per category."] },
    { path = "bar.layout.perLine", page = PAGE, group = LAYOUT, type = "number", min = 0, max = 20, step = 1,
      label = L["Per row or column (0 = one line)"], default = DB.layout.perLine,
      tooltip = L["How many icons a row (or a column, in the vertical layout) holds before the next one starts. 0 keeps each category on one line."] },
    { path = "bar.layout.growH", page = PAGE, group = LAYOUT, type = "string", startsLine = true,
      values = GROW_H, sorting = { "auto", "right", "left" },
      label = L["Grow horizontally"], default = DB.layout.growH,
      tooltip = L["Which way the bar grows when it gets wider. Automatic grows away from the screen edge it is nearest."] },
    { path = "bar.layout.growV", page = PAGE, group = LAYOUT, type = "string",
      values = GROW_V, sorting = { "auto", "down", "up" },
      label = L["Grow vertically"], default = DB.layout.growV,
      tooltip = L["Which way the bar grows when it gets taller. Automatic grows away from the screen edge it is nearest."] },
    { path = "bar.layout.padding", page = PAGE, group = LAYOUT, type = "number", min = 0, max = 20, step = 1,
      startsLine = true, label = L["Padding (px)"], default = DB.layout.padding,
      tooltip = L["Space between the icons and the bar's edge, in pixels."] },
    { path = "bar.layout.spacing", page = PAGE, group = LAYOUT, type = "number", min = 0, max = 20, step = 1,
      label = L["Spacing (px)"], default = DB.layout.spacing,
      tooltip = L["Space between two icons, and between two rows or columns, in pixels."] },
})

-- ── Icons ──────────────────────────────────────────────────────────────────────────────────────
-- Size, then the Border block on the skin's icon family (`fromSkin = "icon"`: its companion governs
-- the thickness too), with *Use the skin's color* after it. Both companions on, the button wears the
-- skin's own window icon outline (S.IconBorder); either off, the player's (modules/Bar_Buttons.lua).
NS.RegisterSchemaRows({
    { path = "bar.icons.size", page = PAGE, group = ICONS, subgroup = L["Size"], type = "number",
      min = 16, max = 64, step = 1, label = L["Icon size (px)"], default = DB.icons.size,
      tooltip = L["The width and height of each outfit icon, in pixels."] },
})
registerComposed(H.BorderGroup({
    prefix = "bar.icons.", page = PAGE, group = ICONS, subgroup = L["Border"], order = 100, show = true,
    fromSkin = "icon", classColor = PLAYER_CLASS,
    defaults = { borderShow = DB.icons.borderShow, borderStyle = DB.icons.borderStyle,
                 borderSize = DB.icons.borderSize, borderColor = DB.icons.borderColor,
                 useClassColorBorder = DB.icons.useClassColorBorder },
    extra = { borderColorFollow("bar.icons.", DB.icons) },
}))

-- ── Labels ─────────────────────────────────────────────────────────────────────────────────────
-- One label per category, over its row (over its column, truncated, in the vertical layout), drawn
-- through S.HudFont (modules/Bar_Chrome.lua). Every row is shown only while the Layout tab's
-- Grouping is Grouped (options-ui-§22: Collapsed draws no labels, and a group no picked value uses is
-- hidden, never dimmed); a note stands in for them while Collapsed. The font block's rows dim while
-- the labels are off, the swatch excepted (it is never grayed, anti-pattern #74); a row the composer
-- already governs by its skin companion dims for either (AuraMaster settings/Layout.lua:582-597's shape).
local GROUPED = { path = "bar.layout.mode", equals = "grouped" }
local function labelsOff() return NS.GetSetting("bar.labels.show") == false end

NS.RegisterSchemaRows({
    { type = "note", page = PAGE, group = LABELS, shownWhen = { path = "bar.layout.mode", equals = "collapsed" },
      text = L["Category labels are drawn only while Grouping is Grouped (Outfit Bar > Layout)."] },
    { path = "bar.labels.show", page = PAGE, group = LABELS, type = "bool", shownWhen = GROUPED,
      label = L["Show category labels"], default = DB.labels.show,
      tooltip = L["Names each row of the bar: Complete outfits, Accessories."] },
})
do
    local d = DB.labels
    local rows = H.FontGroup({
        prefix = "bar.labels.", page = PAGE, group = LABELS, subgroup = L["Font"], order = 100,
        classColor = PLAYER_CLASS, defaults = d, fromSkin = true, flagsFromSkin = true,
        extra = {
            { path = "bar.labels.fontColorFromSkin", type = "bool", startsLine = true,
              label = L["Use the skin's color"], default = d.fontColorFromSkin,
              tooltip = L["Draw the labels in the skin's HUD label color. The Font color swatch is not read while this is on, and Use class color comes first."] },
            { path = "bar.labels.fontShadowFromSkin", type = "bool",
              label = L["Use the skin's shadow"], default = d.fontShadowFromSkin,
              tooltip = L["Draw the labels with the skin's shadow. Font shadow is not read while this is on."] },
        },
    })
    for _, row in ipairs(rows) do
        row.shownWhen = GROUPED
        local governedBy = row.disabledIf
        if type(governedBy) == "string" then
            row.disabledIf = function() return labelsOff() or NS.GetSetting(governedBy) == true end
        elseif row.type ~= "color" then
            row.disabledIf = labelsOff
        end
    end
    registerComposed(rows)
end

-- ── Frame ──────────────────────────────────────────────────────────────────────────────────────
-- The Background block (a backdrop with no texture: a ColorPair, options-ui-§16) and the Border block
-- on the skin's bar family. While *Use the skin's background* is on the bar is drawn exactly as a
-- Ka0s window and these colors wait; off, they draw. The bar always draws one of the two (smoke
-- round 3 E6 removed Show background; a stored `bar.showBackground` is never read).
--
-- SHOW BORDER (smoke round 3 E7, the owner's ruling): while *Use the skin's border* is on the edge is
-- the skin's, in every skin, so the switch is dimmed, reads ticked and is not read; once it is off,
-- the switch shows or hides the edge on either layer. The library's own rule (compose minor 18) dims
-- it only under a skin with a real bar style, so the row's disabledIf and skinValue are replaced here,
-- as the Labels block replaces its rows' (options-ui-§16: its tooltip, through the composer's
-- `tooltips`, says why).
local BORDER_FOLLOWS = "bar.frame.borderStyleFromSkin"
local function borderFollows() return NS.GetSetting(BORDER_FOLLOWS) == true end
registerComposed(H.ColorPair({
    prefix = "bar.", page = PAGE, group = FRAME, subgroup = L["Background"], order = 100,
    key = "bgColor", companionKey = "useClassColorBg", label = L["Background color"], classColor = PLAYER_CLASS,
    defaults = { bgColor = DB.bgColor, useClassColorBg = DB.useClassColorBg },
    extra = { {
        path = "bar.bgFromSkin", type = "bool", startsLine = true, label = L["Use the skin's background"],
        default = DB.bgFromSkin,
        tooltip = L["Draw the bar as a window of the skin: its background, border and header band. While this is on the Background color rows and the border's style, thickness and color are not read; Show border still hides the edge once Use the skin's border is off."],
    } },
}))
do
    local rows = H.BorderGroup({
        prefix = "bar.frame.", page = PAGE, group = FRAME, subgroup = L["Border"], order = 200, show = true,
        fromSkin = "bar", classColor = PLAYER_CLASS, defaults = DB.frame,
        tooltips = { borderShow = L["Draw a border around the bar. While Use the skin's border is on, the border is the skin's, so this switch is dimmed and not read; turn that off to show or hide the border yourself."] },
        extra = { borderColorFollow("bar.frame.", DB.frame) },
    })
    for _, row in ipairs(rows) do
        if row.path == "bar.frame.borderShow" then
            row.disabledIf = borderFollows
            row.skinValue = function() return borderFollows() or nil end
        end
    end
    registerComposed(rows)
end

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
NS.BAR_PAGE = {
    key             = PAGE,
    title           = L["Outfit Bar"],
    panelName       = "OutfitterRebornBarPanel",
    defaultsTooltip = L["Restore every Outfit Bar setting to its default. The bar's position is reset too."],
    -- Reset position after the Display rows: the Master button's twin, the same row's default.
    afterGroup      = { [DISPLAY] = function(ctx)
        return H.InlineButtonPair(ctx, {
            text = L["Reset position"], tooltip = L["Moves the outfit bar back to its starting place."],
            onClick = function() NS.ApplyDefault(NS.FindSchemaRow("bar.position")) end,
        }, nil)
    end },
}

NS.RegisterTabbedPage(NS.BAR_PAGE)
