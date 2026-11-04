local addonName, NS = ...
-- modules/IconBrowserSetup.lua — the LibKa0s-IconBrowser-1.0 lease (sheet and window feedback design
-- G5, G6), the ONE seam the major is reached through (design §2.1). Two surfaces:
--
--   NS.Glyph        the stored shape of an outfit's glyph icon, for the icon model (NS.OutfitIcon, the
--                   `outfit.icon` and `outfit.iconColor` rows, NS.Outfits.SetIcon)
--   NS.IconBrowser  the outfit menu's Change icon...: the library's browser, built once with `IB:New`
--                   (LibKa0s docs/api/IconBrowser/version-1.1.1-docs.md)
--
-- A GLYPH is a LibKa0s catalog icon's texture path (white on transparent, so it takes a tint), and its
-- color six lowercase hex digits, or none for white. A game icon is a fileID number and takes no color.
--
-- THE BROWSER. What is this addon's is the spec handed to the library:
--
--     title    NS.BRAND
--     layers   MODAL (a modal, so the strata over it stays free for AceGUI's pullouts and the color
--              picker, frame-layering-§1) in the band UIParent + ICON_BROWSER, over the outfit dialogs;
--              POPUP for the Wowhead link window (core/Constants.lua LAYERS)
--     tabs     Recommended (the wildcard "Outfitter chooses", the outfit's item icons, every trigger's
--              icon) and Equipped and bags (the inventory cache's items), each named and searched by
--              the item or trigger name, ahead of the library's Game icons and Glyphs
--     hide     Markers: raid markers are not outfit icons
--     print    NS.Print (the combat refusal's gray line); inCombat NS.Compat.InCombatLockdown
--
-- Open(id) hands the library the outfit's stored icon (an Equipment Manager outfit's glyph override,
-- else its set's icon; none is the wildcard) and its color, so it opens on the tab that owns it with it
-- selected. Choose goes to NS.Outfits.SetIcon(id, icon, color), refused in combat by the library;
-- `valid` closes it unwritten when the outfit is gone. While open the outfit window is out of
-- UISpecialFrames (`lift`), so Escape closes the browser only. What closes it, as Cancel: Escape, its
-- X and Cancel, the outfit window hiding (modules/Dock.lua, Close("opener"), the sheet's close among
-- them) and the stand-down (Suspend: the library's StandDown, which also refuses an Open until Resume).
--
-- DEGRADED (the library absent): no path is a glyph, only "none" is a color and every tint is white,
-- so a stored glyph falls through to the next rung of the icon ladder and nothing draws tinted. The
-- browser never opens: Open answers false and Browser() nil.

local IB = LibStub and LibStub("LibKa0s-IconBrowser-1.0", true)

local Glyph = {}
NS.Glyph = Glyph

--- The catalog name of glyph path `v` (at any addon's folder), or nil: a fileID, a texture path, nil.
--- @param v any
--- @return string|nil
function Glyph.IsGlyph(v)
    if not IB then return nil end
    return IB.IsGlyph(v)
end

--- Whether `v` is a stored glyph color: nil, or six lowercase hex digits. `false` (the library's
--- ColorFrom answer for white) is not stored, so it is not one here.
--- @param v any
--- @return boolean
function Glyph.ValidColor(v)
    if v == nil then return true end
    if v == false or not IB then return false end
    return IB.ValidColor(v) == true
end

--- A stored color as r, g, b (0..1): white for none or a malformed one.
--- @param hex string|nil
--- @return number, number, number
function Glyph.Tint(hex)
    if not IB then return 1, 1, 1 end
    return IB.Tint(hex)
end

-- ── the browser ───────────────────────────────────────────────────────────────────────────────

local L = NS.L
local WILDCARD = 134400   -- "Outfitter chooses": SetIcon stores it as no icon
-- The outfit window's global name (modules/Dock.lua), lifted out of UISpecialFrames while open.
local WINDOW_NAME = "OutfitterRebornWindow"

local IconBrowser = {}
NS.IconBrowser = IconBrowser

local browser
local openId   -- the outfit the open browser edits

-- A host tab over `collect(add, rec)`: its icons in first-seen order, each named by what it came from.
local function hostTab(key, label, collect)
    local names = {}
    local function list()
        local icons, seen = {}, {}
        names = {}
        local rec = openId and NS.Outfits.Get(openId)
        if not rec then return icons end
        collect(function(icon, name)
            if type(icon) ~= "number" or seen[icon] then return end
            seen[icon] = true
            icons[#icons + 1] = icon
            names[icon] = name and tostring(name) or nil
        end, rec)
        return icons
    end
    return {
        key = key, label = label, list = list,
        name = function(icon) return names[icon] end,
        owns = function(icon)
            for _, v in ipairs(list()) do if v == icon then return true end end
            return false
        end,
    }
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

--- The library's browser, built on the first ask; nil without the major or the Options instance.
--- @return table|nil
function IconBrowser.Browser()
    if browser then return browser end
    local helpers = NS.Helpers
    if not (IB and IB.New and type(helpers) == "table") then return nil end
    local LAYERS = NS.Constants.LAYERS
    browser = IB:New({
        owner = addonName, title = NS.BRAND, helpers = helpers,
        layers = { strata = LAYERS.STRATA.MODAL, level = LAYERS.LEVEL.ICON_BROWSER, popup = LAYERS.STRATA.POPUP },
        tabs = { hostTab("recommended", L["Recommended"], recommended),
                 hostTab("equipped", L["Equipped and bags"], equipped) },
        hide = { markers = true },
        print = function(line) NS.Print(line) end,
        inCombat = function() return NS.Compat.InCombatLockdown() end,
    })
    return browser
end

-- What the browser opens on: the outfit's stored icon and color. An Equipment Manager outfit's is its
-- glyph override, else its set's icon; none is the wildcard, so "Outfitter chooses" shows selected.
local function stored(rec)
    local icon, color = rec.icon, rec.iconColor
    if rec.kind == "em" then
        icon, color = NS.Outfits.EMGlyph(rec)
        if not icon then icon = NS.EM.Icon(rec) end
    end
    if icon == nil then return WILDCARD, nil end
    return icon, color
end

--- Open the browser on outfit `id` (the outfit menu's Change icon...).
--- @param id string
--- @return boolean opened
function IconBrowser.Open(id)
    local rec = NS.Outfits.Get(id)
    if NS.IsStoodDown() or not rec then return false end
    local b = IconBrowser.Browser()
    if not b then return false end
    if b:IsOpen() then b:Cancel() end
    openId = id
    local icon, color = stored(rec)
    local ok = b:Open({
        icon = icon, color = color, owner = addonName, lift = { WINDOW_NAME },
        valid = function() return NS.Outfits.Get(id) ~= nil end,
        onChoose = function(chosen, c) NS.Outfits.SetIcon(id, chosen, c) end,
    })
    if not ok then openId = nil end
    return ok
end

--- Close without choosing (Escape, the window or the sheet closing, a stand-down).
--- @param reason string|nil  for the caller's record only
function IconBrowser.Close(reason) -- luacheck: ignore 212/reason
    if browser then browser:Cancel() end
end

function IconBrowser.IsOpen() return browser ~= nil and browser:IsOpen() == true end

--- Stand-down: closed, and refused until the stand-up.
function IconBrowser.Suspend()
    if browser then browser:StandDown() end
end

function IconBrowser.Resume()
    if browser then browser:StandUp() end
end
