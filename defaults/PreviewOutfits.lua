local _, NS = ...
-- defaults/PreviewOutfits.lua — the test-mode placeholder outfits (design §8, H17): five sample
-- outfits in the bar's two rows, read by modules/Preview.lua's Source and never by the store.
--
-- The icons are the shipped default trigger icons, so the release Currency check covers them. Each
-- record is stamped `placeholder = true` (every write path in modules/Bar_Buttons.lua checks it first)
-- and `id = "preview:<n>"`, which NS.Outfits.Get never resolves (C28), on the first Rows() read.

local L = NS.L

local rows = {
    { categoryID = "Complete", outfits = {
        { name = L["Test Outfit 1"], icon = 132276 },
        { name = L["Test Outfit 2"], icon = 1376041 },
        { name = L["Test Outfit 3"], icon = 136245 },
    } },
    { categoryID = "Accessory", outfits = {
        { name = L["Test Outfit 4"], icon = 132261 },
        { name = L["Test Outfit 5"], icon = 134062 },
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
