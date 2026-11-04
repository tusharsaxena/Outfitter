local _, NS = ...
-- modules/IconBrowserSetup.lua — NS.Glyph, the LibKa0s-IconBrowser-1.0 lease (sheet and window feedback
-- design G5, G6): the stored shape of an outfit's glyph icon. The ONE seam the major is reached through
-- (design §2.1): plan Task 3.5 leases the glyph helpers for the icon model (NS.OutfitIcon, the
-- `outfit.icon` and `outfit.iconColor` rows, NS.Outfits.SetIcon); Task 3.6 builds the browser here.
--
-- A GLYPH is a LibKa0s catalog icon's texture path (white on transparent, so it takes a tint), and its
-- color six lowercase hex digits, or none for white. A game icon is a fileID number and takes no color.
--
-- DEGRADED (the library absent): no path is a glyph, only "none" is a color and every tint is white,
-- so a stored glyph falls through to the next rung of the icon ladder and nothing draws tinted.

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
