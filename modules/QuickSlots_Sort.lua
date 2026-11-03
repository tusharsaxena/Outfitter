local _, NS = ...
-- modules/QuickSlots_Sort.lua — the flyout's upgrade-track sort (design §7.9, INV §3.11). Extends
-- NS.QuickSlots (modules/QuickSlots.lua, which loads first) with QS.Sort.
--
-- A VERBATIM PORT of OutfitterQuickSlots.lua:42-314 with every comment kept: track ceiling, then
-- TrackStringID, then item level, then name (uncached last), then the flyout's own order; a track
-- counts only while the item can still be upgraded; untracked items are banded into a track.
-- tests/test_quickslots.lua pins it against the legacy capture (tests/fixtures/legacy/quickslots.lua).
--
-- What changed, and only this:
--   * A location unpacks through Compat.FlyoutLocationData. The legacy EquipmentManager_UnpackLocation
--     fallback (Deprecated.QuickSlots.UnpackLocation) is retired.
--   * Links come through Compat.ContainerItemLink and Compat.InventoryItemLink, which hand a secret
--     link back as nil (the Secrets seam's PlainString, the legacy API's Unsecret), and an item
--     location is the addon's plain `loc` table, which only Compat turns into the client's ItemLocation.
--   * C_ItemUpgrade.CanUpgradeItem is pcall'd inside Compat.CanUpgradeItem, which answers nil on a
--     raise, on a missing API and when no item is there: the "nil when it won't" below.
--   * The name and level come from Compat.ItemInfo and the track from Compat.ItemUpgradeInfo, which
--     does not copy the localized trackString: a track is recognized by its trackStringID.
--   * A display location is read through Secrets.PlainNumber, so a value that is not a plain number
--     is left where it is, like the flyout's own entries.
--   * PlaceInBagsLast is the "place in bags" move the legacy postGetItemsFunc wrapper made inline.

local QS = NS.QuickSlots
local Compat, Secrets = NS.Compat, NS.Secrets

local Sort = {}
QS.Sort = Sort

-- The legacy fallback for EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION.
local FIRST_SPECIAL_FALLBACK = 0xFFFFFFFD

-- A FrameXML number by name, plain, or `fallback` when the client has none.
local function clientNumber(name, fallback)
    return Secrets.UnsecretNumber(_G[name], fallback)
end

-- Resolves a packed flyout location to an item link, or nil if the item can't be
-- reached (void storage) or the link came back as a secret value

--- @return string|nil link, table|nil loc  the addon's `{ bag, slot }` or `{ slotID }`
function Sort.LocationItemLink(location)
    local data = Compat.FlyoutLocationData(location)

    if not data then
        return
    end

    local slotIndex, bagIndex = data.slot, data.bag

    if not slotIndex then
        return
    end

    if data.isBags then
        if not bagIndex then
            return
        end

        return Compat.ContainerItemLink(bagIndex, slotIndex), { bag = bagIndex, slot = slotIndex }
    end

    if data.isPlayer
    or data.isBank then
        return Compat.InventoryItemLink(slotIndex), { slotID = slotIndex }
    end
end

-- Returns true or false when the game will say, and nil when it won't

function Sort.ItemCanBeUpgraded(loc)
    if not loc then
        return nil
    end

    return Compat.CanUpgradeItem(loc)
end

-- The track half of GetItemSortInfo, for an item whose link resolved.
local function readTrack(sortInfo, itemLink, itemLocation)
    local upgradeInfo = Compat.ItemUpgradeInfo(itemLink)

    if not (upgradeInfo and upgradeInfo.trackStringID) then
        return
    end

    -- maxItemLevel is where this item's track tops out, which orders the tracks
    -- (Myth over Hero over Champion and so on) as a number, without having to
    -- recognize the track's name.  trackString is localized, so anything keyed
    -- off the name only works on an enUS client

    sortInfo.HasTrack = true
    sortInfo.TrackCeiling = upgradeInfo.maxItemLevel or 0
    sortInfo.TrackStringID = upgradeInfo.trackStringID

    -- Whether the track still has anywhere to go, which is the part that decides
    -- if the track is worth ranking on (see ResolveUpgradableItems)

    sortInfo.HasUpgradeHeadroom = (upgradeInfo.currentLevel or 0) < (upgradeInfo.maxLevel or 0)
    sortInfo.CanUpgrade = Sort.ItemCanBeUpgraded(itemLocation)
end

function Sort.ItemSortInfo(location, index)
    local sortInfo =
    {
        Location = location,
        Index = index,
        TrackCeiling = 0,
        TrackStringID = 0,
        Level = 0,
    }

    local itemLink, itemLocation = Sort.LocationItemLink(location)

    if not itemLink then
        return sortInfo
    end

    local name, _, level = Compat.ItemInfo(itemLink)

    sortInfo.Name = name
    sortInfo.Level = level or 0

    readTrack(sortInfo, itemLink, itemLocation)

    return sortInfo
end

-- A track says how good an item can *become*, which stops being meaningful once it
-- can't be upgraded any more: last season's finished Myth piece would otherwise
-- outrank everything on this season's lower tracks no matter how its item level
-- compares.  Only items which can still be upgraded keep their track; the rest are
-- handed to the banding below and placed on item level, the same as crafted gear

function Sort.ResolveUpgradableItems(sortInfos)
    -- C_ItemUpgrade.CanUpgradeItem is the real answer, but it isn't certain to be
    -- meaningful away from an upgrade vendor.  If it turns up nothing upgradable
    -- while the item data says otherwise, fall back to what the track itself says

    local anyCanUpgrade = false

    for _, sortInfo in ipairs(sortInfos) do
        if sortInfo.CanUpgrade then
            anyCanUpgrade = true
            break
        end
    end

    for _, sortInfo in ipairs(sortInfos) do
        local isUpgradable

        if anyCanUpgrade then
            isUpgradable = sortInfo.CanUpgrade
        else
            isUpgradable = sortInfo.HasUpgradeHeadroom
        end

        sortInfo.OnTrack = (sortInfo.HasTrack and isUpgradable) or false

        if not sortInfo.OnTrack then
            sortInfo.TrackCeiling = 0
            sortInfo.TrackStringID = 0
        end
    end
end

-- The lowest item level seen on each track ceiling, or nil when no item is on a track.
local function trackMinLevels(sortInfos)
    local minLevels

    for _, sortInfo in ipairs(sortInfos) do
        if sortInfo.OnTrack
        and sortInfo.TrackCeiling > 0
        and sortInfo.Level > 0 then
            if not minLevels then
                minLevels = {}
            end

            local minLevel = minLevels[sortInfo.TrackCeiling]

            if not minLevel
            or sortInfo.Level < minLevel then
                minLevels[sortInfo.TrackCeiling] = sortInfo.Level
            end
        end
    end

    return minLevels
end

-- Crafted gear, older gear, and anything which can no longer be upgraded carries no
-- usable track, so rather than dropping it below everything which does, work out
-- which track's item level range it falls in and sort it into that group.  The
-- ranges are taken from the items in this flyout instead of a per-season table, so
-- nothing here needs revisiting when item levels move

function Sort.AssignTrackBands(sortInfos)
    local minLevels = trackMinLevels(sortInfos)

    -- No tracks to compare against, so leave everything as it is and let the
    -- comparator fall through to name and item level

    if not minLevels then
        return
    end

    for _, sortInfo in ipairs(sortInfos) do
        if not sortInfo.OnTrack
        and sortInfo.Level > 0 then
            -- Join the highest track whose range starts at or below this item

            for trackCeiling, minLevel in pairs(minLevels) do
                if sortInfo.Level >= minLevel
                and trackCeiling > sortInfo.TrackCeiling then
                    sortInfo.TrackCeiling = trackCeiling
                end
            end
        end
    end
end

function Sort.CompareItemSortInfo(info1, info2)
    -- Highest upgrade track first, ranked by where the track tops out, which puts
    -- Myth over Hero over Champion and so on.  Untracked items have been given the
    -- ceiling of the track their item level lands in, so only gear below every
    -- track's range is left at 0

    if info1.TrackCeiling ~= info2.TrackCeiling then
        return info1.TrackCeiling > info2.TrackCeiling
    end

    -- Two distinct tracks that happen to top out at the same item level, so keep
    -- each of them together rather than interleaving them

    if info1.OnTrack
    and info2.OnTrack
    and info1.TrackStringID ~= info2.TrackStringID then
        return info1.TrackStringID > info2.TrackStringID
    end

    -- Highest item level next, so within a track the most upgraded pieces come first

    if info1.Level ~= info2.Level then
        return info1.Level > info2.Level
    end

    if info1.Name ~= info2.Name then
        -- Items whose name isn't in the client cache yet go last within their track

        if not info1.Name then
            return false
        end

        if not info2.Name then
            return true
        end

        return info1.Name < info2.Name
    end

    -- Still tied, so keep the order the flyout gave us instead of letting equal
    -- items shuffle each time it's opened

    return info1.Index < info2.Index
end

--- Sort the first `numItems` entries of the flyout's display table in place.
function Sort.Items(itemDisplayTable, numItems)
    if not numItems
    or numItems < 2 then
        return
    end

    -- Locations at or above this are the flyout's own entries (place in bags,
    -- ignore slot) rather than items

    local firstSpecialLocation = clientNumber("EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION", FIRST_SPECIAL_FALLBACK)

    local sortInfos = {}
    local displayIndexes = {}

    for index = 1, numItems do
        local location = Secrets.PlainNumber(itemDisplayTable[index])

        if location
        and location > 0
        and location < firstSpecialLocation then
            table.insert(sortInfos, Sort.ItemSortInfo(location, index))
            table.insert(displayIndexes, index)
        end
    end

    Sort.ResolveUpgradableItems(sortInfos)
    Sort.AssignTrackBands(sortInfos)

    table.sort(sortInfos, Sort.CompareItemSortInfo)

    -- Write the items back into the slots they came from, which leaves the
    -- flyout's own entries where Blizzard put them

    for index, sortInfo in ipairs(sortInfos) do
        itemDisplayTable[displayIndexes[index]] = sortInfo.Location
    end
end

--- If the first item is the PLACEINBAGS item, then move it to the end.
function Sort.PlaceInBagsLast(itemDisplayTable, numItems)
    local placeInBags = clientNumber("EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION", nil)

    if placeInBags
    and (numItems or 0) > 0
    and itemDisplayTable[1] == placeInBags then
        table.remove(itemDisplayTable, 1)
        table.insert(itemDisplayTable, placeInBags)
    end
end
