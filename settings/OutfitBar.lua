local _, NS = ...
-- settings/OutfitBar.lua — the Outfit Bar settings page, `bar` (design §4.2, smoke round 2 design G6),
-- registered between General and Profiles. Tabs: Display (what shows, and the bar's one anchor row,
-- `bar.position`, never drawn), Layout (orientation, wrap, padding, spacing, grow direction), Icons
-- (their size), Labels (each category's, a composed font block) and Frame (the background and the
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
    { path = "bar.combatAlpha", page = PAGE, group = DISPLAY, type = "number", isPercent = true,
      min = 0, max = 1, step = 0.05, label = L["Opacity in combat (%)"], default = DB.combatAlpha,
      tooltip = L["Multiplied by Master opacity on General > Master controls. To hide the bar in combat, set General visibility there."] },
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

NS.RegisterSchemaRows({
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
NS.RegisterSchemaRows({
    { path = "bar.icons.size", page = PAGE, group = ICONS, subgroup = L["Size"], type = "number",
      min = 16, max = 64, step = 1, label = L["Icon size (px)"], default = DB.icons.size,
      tooltip = L["The width and height of each outfit icon, in pixels."] },
})

-- ── Labels ─────────────────────────────────────────────────────────────────────────────────────
-- One label per category, over its row (over its column, truncated, in the vertical layout), drawn
-- through S.HudFont (modules/Bar_Chrome.lua). The font block's rows dim while the labels are off,
-- the swatch excepted (it is never grayed, anti-pattern #74); a row the composer already governs by
-- its skin companion dims for either (AuraMaster settings/Layout.lua:582-597's shape).
local function labelsOff() return NS.GetSetting("bar.labels.show") == false end

NS.RegisterSchemaRows({
    { path = "bar.labels.show", page = PAGE, group = LABELS, type = "bool",
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
-- Show background leads; then the Background block (a backdrop with no texture: a ColorPair,
-- options-ui-§16) and the Border block on the skin's bar family. While *Use the skin's background*
-- is on the bar is drawn exactly as a Ka0s window and these colors wait; off, they draw.
NS.RegisterSchemaRows({
    { path = "bar.showBackground", page = PAGE, group = FRAME, type = "bool",
      label = L["Show background"], default = DB.showBackground,
      tooltip = L["Draws the bar's window behind its buttons: its background, its border and its header band."] },
})
registerComposed(H.ColorPair({
    prefix = "bar.", page = PAGE, group = FRAME, subgroup = L["Background"], order = 100,
    key = "bgColor", companionKey = "useClassColorBg", label = L["Background color"], classColor = PLAYER_CLASS,
    defaults = { bgColor = DB.bgColor, useClassColorBg = DB.useClassColorBg },
    extra = { {
        path = "bar.bgFromSkin", type = "bool", startsLine = true, label = L["Use the skin's background"],
        default = DB.bgFromSkin,
        tooltip = L["Draw the bar as a window of the skin: its background, border and header band. The Background color and Border rows are not read while this is on."],
    } },
}))
registerComposed(H.BorderGroup({
    prefix = "bar.frame.", page = PAGE, group = FRAME, subgroup = L["Border"], order = 200, show = true,
    fromSkin = "bar", classColor = PLAYER_CLASS, defaults = DB.frame,
    extra = { borderColorFollow("bar.frame.", DB.frame) },
}))

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
