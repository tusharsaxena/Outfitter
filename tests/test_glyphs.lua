-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (localization-§7; the
-- kit's tests/_kit/glyphs.lua, design §9.3).
--
-- Every skin draws this addon's text in its own faces, and a character one of them lacks is a box in
-- that skin only. So every string literal in a tracked .lua file outside libs/, tests/ and tools/
-- carries only characters every shipped face draws (the kit's safe set, read from their cmaps). A
-- string drawn in the mono role carries a `glyph: mono` marker; a string that is data and never drawn
-- carries a `glyph: data` marker with its reason. The locale files are scanned too: a translation's
-- values are literals like any other.

local T = _G.OUTFITTERREBORN_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
    -- red under: a ≈, →, ▸, ▼ or ▲ (or any other character outside the kit's safe set) in a string
    -- the addon paints in a skin face, unmarked.
    T.assertDisplayGlyphs{ label = "OutfitterReborn" }
end)
