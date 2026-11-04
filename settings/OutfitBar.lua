local _, NS = ...
-- settings/OutfitBar.lua — the Outfit Bar settings page, `bar` (design §4.2, smoke round 2 design G6),
-- registered between General and Profiles. Tabs: Display (what shows, and the bar's one anchor row,
-- `bar.position`, never drawn), Layout (orientation, wrap, padding, spacing, grow direction) and
-- Icons (their size). Scale, opacity and the lock stay the Master controls' (options-ui-§15): the
-- bar is the one frame they govern.
--
-- The bar re-renders on SETTINGS_CHANGED for any `bar.*` path (modules/Bar.lua), so no row here needs
-- an onChange: the panel, `/or set` and a reset all reach the bar the same way.

local L = NS.L
local D = NS.defaults.profile
local PAGE = "bar"
local DISPLAY = L["Display"]
local LAYOUT = L["Layout"]
local ICONS = L["Icons"]
local DB = D.bar

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
    { path = "bar.showBackground", page = PAGE, group = DISPLAY, type = "bool",
      label = L["Show background"], default = DB.showBackground,
      tooltip = L["Draws a backplate behind the bar's buttons."] },
    { path = "bar.combatAlpha", page = PAGE, group = DISPLAY, type = "number", isPercent = true,
      min = 0, max = 1, step = 0.05, label = L["Opacity in combat (%)"], default = DB.combatAlpha,
      tooltip = L["Multiplied by Master opacity on General > Master controls."] },
    -- Never drawn: the drag handle places the bar, and Reset position (General > Master controls)
    -- resets this row. Its own get/set are its storage.
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

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
NS.BAR_PAGE = {
    key             = PAGE,
    title           = L["Outfit Bar"],
    panelName       = "OutfitterRebornBarPanel",
    defaultsTooltip = L["Restore every Outfit Bar setting to its default. The bar's position is reset too."],
}

NS.RegisterTabbedPage(NS.BAR_PAGE)
