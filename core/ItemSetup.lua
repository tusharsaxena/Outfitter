local _, NS = ...
-- core/ItemSetup.lua — NS.Item, the LibKa0s-Item-1.0 v3 lease: an item link's id and its bonus ids (H15).
--
-- The lease is the two identity primitives modules/ItemInfo.lua builds ParseLink on (design §5.3):
-- the itemID and the bonus list, both read off the link's own structure and never off a displayed
-- name. The rest of the major (QualityFromLink, QualityLabel, LoadItem) is not leased: nothing here
-- calls it. The data file defaults/Items.lua publishes NS.ItemData, a different name on purpose (C38).
--
-- A link is read only when it is a PLAIN string (NS.Secrets.PlainString, at call time): a secret
-- link answers nil, the same answer as an empty slot (design §2.2), and is never matched.
--
-- DEGRADED (the library absent): the same two walks as the library's own, written out here as the
-- documented duplication a degrade stub carries. tests/test_surface_parity.lua pins them to the
-- library on the same links, so the copy cannot drift.

local Item = LibStub and LibStub("LibKa0s-Item-1.0", true)

local itemID, bonusIDs
if Item then
    itemID, bonusIDs = Item.ItemIDFromLink, Item.BonusIDsFromLink
else
    itemID = function(link)
        return tonumber(link:match("|?H?item:(%d+)"))
    end
    -- Field 13 is the declared bonus count n and fields 14..13+n are the ids; empty fields are kept
    -- when splitting, because the itemString is positional.
    bonusIDs = function(link)
        local body = link:match("item:([%-%d:]*)")
        if not body then return nil end
        local fields = {}
        for v in (body .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = v end
        if not tonumber(fields[1]) then return nil end
        local out = {}
        for i = 14, 13 + (tonumber(fields[13]) or 0) do
            local id = tonumber(fields[i])
            if id then out[#out + 1] = id end
        end
        return out
    end
end

NS.Item = {}

--- The itemID an item link or a bare itemString carries, or nil (no item, not a string, or secret).
--- @param link any
--- @return number|nil
function NS.Item.ItemIDFromLink(link)
    local plain = NS.Secrets.PlainString(link)
    if not plain then return nil end
    return itemID(plain)
end

--- The bonus ids an item link carries, as numbers in link order: {} for none, nil for no item, a
--- non-string or a secret.
--- @param link any
--- @return number[]|nil
function NS.Item.BonusIDsFromLink(link)
    local plain = NS.Secrets.PlainString(link)
    if not plain then return nil end
    return bonusIDs(plain)
end
