local _, NS = ...
-- defaults/PreviewOutfits.lua — the test-mode placeholder outfits (design §8; smoke round 2 design
-- G7): five sample outfits in two rows, read by modules/Preview.lua's Source (the bar) and by
-- modules/Window_ListModel.lua (the window), never by the store.
--
-- The icons are shipped default trigger icons, so the release Currency check covers them; two
-- samples carry none and resolve through NS.OutfitIcon like a real outfit: Test Outfit 3, keyed as
-- a seeded spec outfit, draws the first specialization's icon, and Test Outfit 5 the default 132724.
-- The window-only display fields show one row feature each, and the bar ignores them: `worn` (the
-- worn box), `triggered` (the lightning), `em` (the Equipment Manager mark) and `status` (the name's
-- color). Each record is stamped `placeholder = true` (every write path in modules/Bar_Buttons.lua
-- and modules/Window_Rows.lua checks it first) and `id = "preview:<n>"`, which NS.Outfits.Get never
-- resolves (C28), on the first Rows() read.

local L = NS.L

local rows = {
    { categoryID = "Complete", outfits = {
        { name = L["Test Outfit 1"], icon = 132276, worn = true },
        { name = L["Test Outfit 2"], icon = 1376041, triggered = true },
        { name = L["Test Outfit 3"], builtin = "SPEC_1" },
    } },
    { categoryID = "Accessory", outfits = {
        { name = L["Test Outfit 4"], icon = 132261, em = true },
        { name = L["Test Outfit 5"], status = "missing" },
    } },
}

local stamped = false

--- Stamp every record once: the placeholder flag and its `preview:<n>` id, numbered across the rows.
local function stamp()
    local n = 0
    for _, row in ipairs(rows) do
        for _, rec in ipairs(row.outfits) do
            n = n + 1
            rec.placeholder, rec.id = true, "preview:" .. n
        end
    end
    stamped = true
end

NS.PreviewOutfits = { rows = rows }

--- The sample rows, in the shape the bar's sources answer: { { categoryID, outfits = { rec, ... } } }.
--- @return table[]
function NS.PreviewOutfits.Rows()
    if not stamped then stamp() end
    return rows
end
