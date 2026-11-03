-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (localization-§7; the
-- kit's tests/_kit/glyphs.lua, design §9.3).
--
-- Every skin draws this addon's text in its own faces, and a character one of them lacks is a box in
-- that skin only. So every string literal in a tracked .lua file outside libs/, tests/ and tools/
-- carries only characters every shipped face draws (the kit's safe set, read from their cmaps). A
-- string drawn in the mono role carries a `glyph: mono` marker; a string that is data and never drawn
-- carries a `glyph: data` marker with its reason. The locale files are scanned too: a translation's
-- values are literals like any other, and the deDE and frFR overlays stay inside the safe set.
--
-- The four overlays in another script are left out, each with its reason (design §4.6 Font fallback,
-- H8): their text is Hangul, Han or Cyrillic, which the western safe set cannot hold, and it is only
-- ever drawn on a client of that locale. There LibKa0s-Skin refuses a shipped face whose langmask
-- leaves the locale out (libs/LibKa0s/Skin.lua, faceRefused). Whether the face it lands on draws the
-- script is the client check H8 names; if it does not, conditional row D7 is written.

local T = _G.OUTFITTERREBORN_TEST
local test = T.test

local LOCALE_SCRIPT = "a translation drawn only on a client of its own locale, where LibKa0s-Skin "
    .. "refuses a face whose langmask leaves that locale out; the client check is H8 (conditional D7)"

local SKIP = {
    ["locales/zhCN.lua"] = LOCALE_SCRIPT,
    ["locales/zhTW.lua"] = LOCALE_SCRIPT,
    ["locales/koKR.lua"] = LOCALE_SCRIPT,
    ["locales/ruRU.lua"] = LOCALE_SCRIPT,
}

test("glyphs: display strings use only characters every shipped skin face draws", function()
    -- red under: a ≈, →, ▸, ▼ or ▲ (or any other character outside the kit's safe set) in a string
    -- the addon paints in a skin face, unmarked; or a Han, Hangul or Cyrillic character in the deDE
    -- or frFR overlay.
    T.assertDisplayGlyphs{ label = "OutfitterReborn", skip = SKIP }
end)

test("glyphs: only the four overlays in another script are left out", function()
    -- red under: a skip for a western overlay or for any file outside locales/.
    local allowed = { zhCN = true, zhTW = true, koKR = true, ruRU = true }
    for path in pairs(SKIP) do
        local loc = path:match("^locales/(%a%a%a%a)%.lua$")
        T.assertTrue(loc ~= nil and allowed[loc], path .. " is skipped but is not a CJK or Cyrillic overlay")
    end
end)
