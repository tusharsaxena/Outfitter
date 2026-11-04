local _, NS = ...
-- modules/Window_ListModel.lua — NS.WindowListModel: what the outfit list shows, in order (design §7.3,
-- INV §7.2). PURE: it builds entries and draws nothing, so modules/Window.lua renders it and
-- tests/test_list_model.lua reads it without a frame.
--
-- THE ORDER. The outfit categories (O.Categories: Complete, then Accessory), each header always
-- shown and its outfits sorted by name, nil names last, the EM copy first on a tie
-- (Outfitter.CompareOutfitNames, Outfitter.lua:3075). Then the item sections Inventory answers
-- (Odds 'n ends, Warbound until equipped, Unopened), each already sorted by
-- NS.Inventory.CompareItems and left out when empty. A collapsed category keeps its header.
--
-- AN ENTRY is { kind, id, depth } plus, per kind: a category's `label`, `desc` and `collapsed`; an
-- outfit's `status` (read through the status cache); an item's `item` (the info).
--
-- CALLS (at call time; design §12): NS.Outfits.Categories/Ids/Get/Status, NS.Inventory.ItemSections.

local LM = {}
NS.WindowListModel = LM

local L = NS.L

-- Each header's label and its hover description (cCompleteOutfits .. cWarboundCategoryDescription).
-- The item sections are keyed by Inventory's section key; its labelKey is the same enUS text.
local LABEL = {
    Complete = L["Complete outfits"],
    Accessory = L["Accessories"],
    unused = L["Odds 'n ends"],
    warbound = L["Warbound until equipped"],
    boe = L["Unopened"],
}
local DESC = {
    Complete = L["Complete outfits have all slots specified. Wearing one takes every other outfit off."],
    Accessory = L["Accessory outfits have some, but not all, slots specified. You can wear as many as you like at once."],
    unused = L["Odds 'n ends lists the soulbound items none of your outfits uses."],
    warbound = L["Warbound until equipped lists the warbound items that become soulbound once equipped."],
    boe = L["Unopened lists the items still in their original Binds on Equip state."],
}
LM.LABEL, LM.DESC = LABEL, DESC

--- The outfit list's order: by name, a nil name last, then the EM copy first, then by id.
--- @param a table { id, name, em }
--- @param b table
--- @return boolean
function LM.CompareOutfits(a, b)
    if a.name ~= b.name then
        if a.name == nil then return false end
        if b.name == nil then return true end
        return a.name < b.name
    end
    if a.em ~= b.em then return a.em end
    return a.id < b.id
end

--- One category's outfit ids in display order.
--- @param category string
--- @return string[]
function LM.SortedIds(category)
    local O = NS.Outfits
    local keyed = {}
    for _, id in ipairs(O.Ids(category)) do
        local rec = O.Get(id)
        local name = rec and rec.name
        keyed[#keyed + 1] = { id = id, name = type(name) == "string" and name or nil, em = rec ~= nil and rec.kind == "em" }
    end
    table.sort(keyed, LM.CompareOutfits)
    local out = {}
    for i, k in ipairs(keyed) do out[i] = k.id end
    return out
end

--- O.Status through `statusCache` (id -> status, false for none; not the inventory cache); the
--- window wipes it on MarkDirty(true).
--- @param id string
--- @param statusCache table
--- @return string|nil
function LM.Status(id, statusCache)
    local s = statusCache[id]
    if s == nil then
        s = NS.Outfits.Status(id) or false
        statusCache[id] = s
    end
    return s or nil
end

local function header(out, id, collapsed, labelKey)
    out[#out + 1] = {
        kind = "category", id = id, depth = 0,
        label = LABEL[id] or (labelKey and L[labelKey]) or tostring(id),
        desc = DESC[id],
        collapsed = collapsed[id] == true or nil,
    }
    return collapsed[id] ~= true
end

--- The list's entries, top to bottom.
--- @param collapsed table|nil  category id -> true (session only)
--- @param statusCache table|nil  id -> status (LM.Status)
--- @return table[]
function LM.Build(collapsed, statusCache)
    collapsed, statusCache = collapsed or {}, statusCache or {}
    local out = {}
    for _, cat in ipairs(NS.Outfits.Categories()) do
        if header(out, cat, collapsed) then
            for _, id in ipairs(LM.SortedIds(cat)) do
                out[#out + 1] = { kind = "outfit", id = id, depth = 1, status = LM.Status(id, statusCache) }
            end
        end
    end
    for _, section in ipairs(NS.Inventory.ItemSections()) do
        if header(out, section.key, collapsed, section.labelKey) then
            for i, item in ipairs(section.items) do
                out[#out + 1] = { kind = "item", id = section.key .. ":" .. i, depth = 1, item = item }
            end
        end
    end
    return out
end
