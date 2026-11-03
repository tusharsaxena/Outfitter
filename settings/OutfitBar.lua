local _, NS = ...
-- settings/OutfitBar.lua — the Outfit Bar settings page, `bar` (design §4.2), registered between General
-- and Profiles. One tab, "Display": the bar has no size row (scale is a Master control) and its one
-- anchor row, `bar.position`, is never drawn, so neither "Size and position" nor "Layout" fits it
-- (options-ui-§16).
--
-- The bar re-renders on SETTINGS_CHANGED for any `bar.*` path (modules/Bar.lua), so no row here needs
-- an onChange: the panel, `/of set` and a reset all reach the bar the same way.

local L = NS.L
local D = NS.defaults.profile
local PAGE = "bar"
local DISPLAY = L["Display"]

-- ── bar.position ────────────────────────────────────────────────────────────────────────────────
-- A string row over the named non-setting state `profile.windows.bar` (`{ point, x, y }`, design §3.4)
-- so `/of get|set|reset bar.position` reach the bar's place (the old `reset bar`, H5). Its default is
-- the defaults tree's, encoded, and every write decodes into a NEW table, so a reset copies the
-- default and never aliases it (the legacy aliased it: OutfitterBar.lua:107-115).
local CORNERS = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

--- A coordinate as text: whole numbers bare, anything else to two places without trailing zeros.
local function coord(n)
    if n == math.floor(n) then return ("%d"):format(n) end
    return (("%.2f"):format(n):gsub("0+$", ""):gsub("%.$", ""))
end

--- `{ point, x, y }` as `POINT X Y`.
local function encode(p) return p.point .. " " .. coord(p.x) .. " " .. coord(p.y) end

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
      label = L["Show outfit bar"], default = D.bar.shown,
      tooltip = L["Shows a bar of outfit buttons you can click to wear or remove an outfit."] },
    { path = "bar.vertical", page = PAGE, group = DISPLAY, type = "bool",
      label = L["Vertical layout"], default = D.bar.vertical,
      tooltip = L["One column per category."] },
    { path = "bar.showBackground", page = PAGE, group = DISPLAY, type = "bool",
      label = L["Show background"], default = D.bar.showBackground,
      tooltip = L["Draws a backplate behind the bar's buttons."] },
    { path = "bar.combatAlpha", page = PAGE, group = DISPLAY, type = "number", isPercent = true,
      min = 0, max = 1, step = 0.05, label = L["Opacity in combat (%)"], default = D.bar.combatAlpha,
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

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
NS.BAR_PAGE = {
    key             = PAGE,
    title           = L["Outfit Bar"],
    panelName       = "OutfitterRebornBarPanel",
    defaultsTooltip = L["Restore every Outfit Bar setting to its default. The bar's position is reset too."],
}

NS.RegisterTabbedPage(NS.BAR_PAGE)
