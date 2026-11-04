-- tests/test_quickslots.lua — P4.18's flyout quick slots (design §7.9, INV §3.11): modules/QuickSlots.lua's
-- hooks and modules/QuickSlots_Sort.lua's upgrade-track sort.
--
-- The sort is pinned against the legacy capture (tests/fixtures/legacy/quickslots.lua) flyout by
-- flyout, through the whole client path: each fixture item sits in bag 0 at the slot of its index,
-- so a location unpacks through Compat.FlyoutLocationData, its link comes through the container
-- read, and its name, level and track through the C_Item reads the case answers. Then the upgrade
-- answer (a raise reads as "the game won't say", and the headroom fallback takes over), the untracked
-- banding, the specials and "place in bags", the equipped-item filter, the PostClick that opens or
-- closes the flyout, the secret or void location, and the two gates every hook body reads: the latch
-- and `quickSlots.enabled`.
--
-- THE FLYOUT STAND-IN. The mock's PaperDollItemsFrame.flyoutSettings is an empty table; each case
-- that drives the hooks gives it the two functions the client's flyout calls, marks it hookable (the
-- mock's hooksecurefunc then really post-hooks it, mock_world.lua), and models the one behavior the
-- design leans on: the original postGetItemsFunc inserts "place in bags" at index 1 and answers
-- numItems + 1, which a post-hook never sees (design §7.9).
--
-- No module QuickSlots calls is owned by a later group, so no case installs a fake (design §12).

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db

-- The client's packed-location bits (ITEM_INVENTORY_LOCATION_*), as the gear mock answers them.
local PLAYER, BAGS, BANK = 0x00100000, 0x00200000, 0x00400000
-- The flyout's special entries, as this suite's stand-in client defines them: every location at or
-- above FIRST_SPECIAL is the flyout's own (ignore slot, place in bags), never an item.
local FIRST_SPECIAL, UNIGNORE, PLACE_IN_BAGS = 0xFFFFFFFC, 0xFFFFFFFD, 0xFFFFFFFE

local function bagLoc(bag, slot) return PLAYER + BAGS + bag * 256 + slot end

local function QS(NS) return NS.QuickSlots end

-- ── the instances ────────────────────────────────────────────────────────────────────────────────

-- An instance with the flyout stand-in installed, a gear scenario loaded, and the hooks built
-- (Resume is the lifecycle's stand-up, which is where the hooks are built). `M.__flyout` records
-- what the hooks asked of the client: the popout buttons clicked and the hides.
local function flyoutInstance(scenario)
    local inst = unitLoad({ mutate = function(M)
        if scenario then M.__gear:load(scenario) end
        local rec = { source = {}, clicked = {}, hidden = 0 }
        M.__flyout = rec
        local fs = M.PaperDollItemsFrame.flyoutSettings
        fs.getItemsFunc = function(_, itemTable)
            for location, itemID in pairs(rec.source) do itemTable[location] = itemID end
        end
        fs.postGetItemsFunc = function(_, display, numItems)
            table.insert(display, 1, PLACE_IN_BAGS)
            return numItems + 1
        end
        M.__hookable[fs] = true
        M.EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION = FIRST_SPECIAL
        M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
        local frame = M.CreateFrame("Frame", "EquipmentFlyoutFrame", M.UIParent)
        frame:Hide()
        M.EquipmentFlyout_Hide = function()
            rec.hidden = rec.hidden + 1
            frame.button = nil
            frame:Hide()
        end
        -- The client's toggle (EquipmentFlyoutPopoutButton_OnClick): it keys on flyoutLocked, and
        -- EquipmentFlyout_Hide above leaves the lock as it was.
        M.EquipmentFlyoutPopoutButton_OnClick = function(popout)
            rec.clicked[#rec.clicked + 1] = popout
            if popout.flyoutLocked then
                popout.flyoutLocked, popout.reversed = false, false
                M.EquipmentFlyout_Hide()
            else
                popout.flyoutLocked, popout.reversed = true, true
                frame.button = popout.owner
                frame:Show()
            end
        end
        for _, b in pairs(M.__slotButtons) do b.popoutButton = { owner = b } end
    end })
    QS(inst.NS).Resume()
    return inst, inst.NS, inst.mocks
end

-- How many post-hooks the mock recorded on the flyout settings.
local function flyoutHooks(M)
    local n = 0
    for _, h in ipairs(M.__hooks) do
        if h.target == M.PaperDollItemsFrame.flyoutSettings then n = n + 1 end
    end
    return n
end

-- The client's flyout run: getItemsFunc fills a fresh table, which is answered.
local function flyoutItems(M, slotID)
    local items = {}
    M.PaperDollItemsFrame.flyoutSettings.getItemsFunc(slotID, items)
    return items
end

-- The client's display pass: postGetItemsFunc over `display`, as the caller's numItems.
local function flyoutDisplay(M, display)
    M.PaperDollItemsFrame.flyoutSettings.postGetItemsFunc(nil, display, #display)
    return display
end

-- An instance whose client answers each bag 0 slot from `state.items` (a fixture flyout's items):
-- the link, the name and base level, the upgrade track, and the upgrade answer `state.canUpgrade`
-- (a function, so a case can make it raise).
local function sortInstance()
    local inst = unitLoad()
    local M = inst.mocks
    local state = { items = {}, canUpgrade = function() return false end }
    local function recOf(link) return state.items[tonumber(link:match("item:(%d+)"))] end
    M.C_Container.GetContainerItemLink = function(bag, slot)
        if bag == 0 and state.items[slot] then return "|cffffffff|Hitem:" .. slot .. "::|h[x]|h|r" end
        return nil
    end
    M.C_Item.GetItemInfo = function(link)
        local rec = recOf(link)
        if not rec then return nil end
        return rec.name, link, 1, rec.level
    end
    M.C_Item.GetItemUpgradeInfo = function(link)
        local rec = recOf(link)
        return rec and rec.track
    end
    M.C_Item.DoesItemExist = function(il) return il.bag == 0 and state.items[il.slot] ~= nil end
    M.C_ItemUpgrade.CanUpgradeItem = function(il) return state.canUpgrade(il.slot) end
    return inst, state
end

-- Sort `display` (fixture indexes and specials) as bag 0 locations; answer it in fixture indexes.
local function sortIndexes(NS, display)
    local locs = {}
    for i, v in ipairs(display) do locs[i] = (v < FIRST_SPECIAL) and bagLoc(0, v) or v end
    QS(NS).Sort.Items(locs, #locs)
    local out = {}
    for i, v in ipairs(locs) do out[i] = (v < FIRST_SPECIAL) and (v - bagLoc(0, 0)) or v end
    return table.concat(out, ",")
end

-- ── surface ──────────────────────────────────────────────────────────────────────────────────────

test("quickslots: NS.QuickSlots and its sort are published", function()
    local Q = QS(T.NS)
    assertEqual(type(Q), "table", "NS.QuickSlots")
    for _, name in ipairs({ "Install", "Suspend", "Resume", "SetEnabled", "CurrentSlot" }) do
        assertEqual(type(Q[name]), "function", "QuickSlots." .. name)
    end
    for _, name in ipairs({ "Items", "PlaceInBagsLast", "CompareItemSortInfo", "ItemSortInfo",
                            "LocationItemLink", "ItemCanBeUpgraded", "ResolveUpgradableItems",
                            "AssignTrackBands" }) do
        assertEqual(type(Q.Sort[name]), "function", "QuickSlots.Sort." .. name)
    end
end)

test("quickslots: the hooks are post-hooks, built once however often the addon stands up", function()
    local _, NS, M = flyoutInstance("secret_slots")
    -- red under: replacing flyoutSettings.getItemsFunc with a wrapper (the legacy replacement,
    -- OutfitterQuickSlots.lua:17), which the mock's hooksecurefunc never records.
    assertEqual(flyoutHooks(M), 2, "getItemsFunc and postGetItemsFunc are hooksecurefunc'd")
    QS(NS).Resume()
    QS(NS).Install()
    QS(NS).SetEnabled(true)
    -- red under: dropping the `installed` guard in QuickSlots.Install (each stand-up hooks again).
    assertEqual(flyoutHooks(M), 2, "a second stand-up hooked the flyout again")
    M.__slotButtons.LegsSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#M.__flyout.clicked, 1, "a second stand-up hooked the slot button again")
end)

test("quickslots: a client without the flyout functions builds the slot hooks and raises nothing", function()
    -- The bare mock: flyoutSettings is an empty table. hooksecurefunc on a missing member raises in
    -- the client, so this instance's raises too.
    local inst = unitLoad({ mutate = function(M)
        local base = M.hooksecurefunc
        M.hooksecurefunc = function(t, name, fn)
            if type(t) == "table" and type(rawget(t, name)) ~= "function" then
                error("hooksecurefunc(): " .. tostring(name) .. " is not a function", 2)
            end
            return base(t, name, fn)
        end
    end })
    -- red under: dropping the member check in QuickSlots.lua's hookFlyout.
    QS(inst.NS).Resume()
    assertEqual(flyoutHooks(inst.mocks), 0)
    assertEqual(type(inst.mocks.__slotButtons.HeadSlot:GetScript("PostClick")), "function",
        "the slot buttons are hooked regardless")
end)

-- ── the sort, against the legacy capture ─────────────────────────────────────────────────────────

test("quickslots: the sort equals the legacy capture, flyout by flyout", function()
    local inst, state = sortInstance()
    local flyouts = T.legacy.quickslots.flyouts
    assertTrue(#flyouts >= 5, "the capture holds no flyouts; nothing below can fail")
    for _, f in ipairs(flyouts) do
        state.items = f.items
        local upgradable = f.canUpgrade or {}
        state.canUpgrade = function(slot) return upgradable[slot] == true end
        local display = {}
        for i = 1, #f.items do display[i] = i end
        if f.special then display = { 1, UNIGNORE, 2 } end
        assertEqual(sortIndexes(inst.NS, display), table.concat(f.order, ","), f.name)
    end
end)

test("quickslots: CanUpgradeItem decides once any item answers yes; else the headroom does", function()
    local inst, state = sortInstance()
    local function track(id, max, cur) return { trackStringID = id, maxItemLevel = max, currentLevel = cur, maxLevel = 8 } end
    -- Both items have headroom; item 1's track tops out higher, item 2 is the one the game upgrades.
    state.items = {
        [1] = { name = "Hero", level = 600, track = track(2, 626, 2) },
        [2] = { name = "Champion", level = 610, track = track(1, 619, 2) },
    }
    state.canUpgrade = function() return false end
    -- No item answers yes, so the headroom decides: both keep their tracks, the higher one first.
    assertEqual(sortIndexes(inst.NS, { 1, 2 }), "1,2", "the headroom fallback")
    state.canUpgrade = function(slot) return slot == 2 end
    -- red under: ResolveUpgradableItems reading HasUpgradeHeadroom regardless of the answer.
    assertEqual(sortIndexes(inst.NS, { 1, 2 }), "2,1", "a yes from the game outranks the headroom")
end)

test("quickslots: a raising CanUpgradeItem reads as 'the game won't say', and the sort goes on", function()
    local inst, state = sortInstance()
    local Sort = QS(inst.NS).Sort
    local function track(id, max, cur) return { trackStringID = id, maxItemLevel = max, currentLevel = cur, maxLevel = 8 } end
    state.items = {
        [1] = { name = "Champion", level = 600, track = track(1, 610, 2) },
        [2] = { name = "Old Hero", level = 590, track = track(2, 626, 8) },
    }
    state.canUpgrade = function() error("CanUpgradeItem: not at an upgrade vendor") end
    -- red under: calling C_ItemUpgrade.CanUpgradeItem unprotected (Compat.CanUpgradeItem's pcall).
    assertNil(Sort.ItemCanBeUpgraded({ bag = 0, slot = 1 }), "a raise is no answer")
    -- red under: reading a raise as a yes (item 2 would keep its 626 track and come first).
    assertEqual(sortIndexes(inst.NS, { 1, 2 }), "1,2", "the headroom fallback after a raise")
    assertNil(Sort.ItemCanBeUpgraded(nil), "no location, no answer")
    state.canUpgrade = function() return true end
    assertNil(Sort.ItemCanBeUpgraded({ bag = 0, slot = 9 }), "no item there, no answer")
    assertEqual(Sort.ItemCanBeUpgraded({ bag = 0, slot = 1 }), true)
end)

test("quickslots: an untracked item joins the highest track whose range starts at or below it", function()
    local inst, state = sortInstance()
    local function track(id, max, cur) return { trackStringID = id, maxItemLevel = max, currentLevel = cur, maxLevel = 8 } end
    state.items = {
        [1] = { name = "Champion", level = 600, track = track(1, 610, 2) },
        [2] = { name = "Hero", level = 615, track = track(2, 626, 2) },
        [3] = { name = "Crafted high", level = 620 },   -- in the Hero range (615+): ceiling 626
        [4] = { name = "Crafted mid", level = 605 },    -- in the Champion range only: ceiling 610
        [5] = { name = "Crafted low", level = 500 },    -- below every range: stays at 0, last
    }
    -- red under: AssignTrackBands joining the LOWEST qualifying track (item 3 would sort after 2's
    -- track as a 610), or skipping the banding (items 3 and 4 would sink below every tracked item).
    assertEqual(sortIndexes(inst.NS, { 5, 4, 3, 2, 1 }), "3,2,4,1,5")
    local infos = { { OnTrack = false, Level = 640, TrackCeiling = 0 } }
    QS(inst.NS).Sort.AssignTrackBands(infos)
    assertEqual(infos[1].TrackCeiling, 0, "no tracked item in the flyout, nothing to band into")
end)

test("quickslots: an item the client cannot place keeps the defaults and sorts last", function()
    local inst, state = sortInstance()
    state.items = { [1] = { name = "Here", level = 600 } }
    local info = QS(inst.NS).Sort.ItemSortInfo(bagLoc(0, 7), 3)
    assertEqual(info.Location, bagLoc(0, 7))
    assertEqual(info.Index, 3)
    assertEqual(info.Level, 0)
    assertEqual(info.TrackCeiling, 0)
    assertNil(info.Name)
    assertNil(info.HasTrack)
    assertEqual(sortIndexes(inst.NS, { 7, 1 }), "1,7")
end)

-- ── the specials and "place in bags" ─────────────────────────────────────────────────────────────

test("quickslots: the sort counts the dense table, and 'place in bags' moves to the end", function()
    local inst, state = sortInstance()
    local M = inst.mocks
    state.items = { [1] = { name = "Low", level = 500 }, [2] = { name = "High", level = 700 } }
    local fs = M.PaperDollItemsFrame.flyoutSettings
    fs.postGetItemsFunc = function(_, display, numItems)
        table.insert(display, 1, PLACE_IN_BAGS)
        return numItems + 1
    end
    M.__hookable[fs] = true
    M.EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION = FIRST_SPECIAL
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
    QS(inst.NS).Resume()
    local display = flyoutDisplay(M, { bagLoc(0, 1), bagLoc(0, 2) })
    -- red under: sorting with the caller's numItems (2) rather than #display (3): only "place in bags"
    -- and Low would be looked at, and Low would stay first.
    assertEqual(display[1], bagLoc(0, 2), "High first")
    assertEqual(display[2], bagLoc(0, 1), "Low second")
    -- red under: dropping Sort.PlaceInBagsLast from the postGetItemsFunc hook.
    assertEqual(display[3], PLACE_IN_BAGS, "place in bags last")
    assertEqual(#display, 3, "nothing added or lost")
end)

test("quickslots: a special entry anywhere but first stays where the flyout put it", function()
    local inst = unitLoad()
    local M, Sort = inst.mocks, QS(inst.NS).Sort
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = PLACE_IN_BAGS
    local t = { 11, PLACE_IN_BAGS, 12 }
    Sort.PlaceInBagsLast(t, 3)
    assertEqual(table.concat(t, ","), "11," .. PLACE_IN_BAGS .. ",12", "only a leading 'place in bags' moves")
    t = { PLACE_IN_BAGS, 11 }
    Sort.PlaceInBagsLast(t, 2)
    assertEqual(table.concat(t, ","), "11," .. PLACE_IN_BAGS)
    M.EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION = nil
    t = { PLACE_IN_BAGS, 11 }
    Sort.PlaceInBagsLast(t, 2)
    assertEqual(t[1], PLACE_IN_BAGS, "a client without the constant moves nothing")
    t = { 5 }
    Sort.Items(t, 1)
    assertEqual(t[1], 5, "a one-item flyout is left alone")
end)

-- ── the filter ───────────────────────────────────────────────────────────────────────────────────

test("quickslots: items already on the player leave the flyout; bag and bank items stay", function()
    local _, _, M = flyoutInstance("secret_slots")
    local worn, carried = PLAYER + 5, bagLoc(0, 2)
    local banked, bankBag = PLAYER + BANK + 40, PLAYER + BANK + BAGS + 6 * 256 + 1
    M.__flyout.source = { [worn] = 1, [carried] = 2, [banked] = 3, [bankBag] = 4 }
    local items = flyoutItems(M, 5)
    assertNil(items[worn], "the worn chest is filtered out")
    assertEqual(items[carried], 2, "a bag item stays")
    -- red under: a mask of PLAYER + BAGS only (the bank's main slots carry PLAYER + BANK and would
    -- read as worn).
    assertEqual(items[banked], 3, "a bank slot stays")
    assertEqual(items[bankBag], 4, "a bank bag item stays")
end)

-- ── PostClick ────────────────────────────────────────────────────────────────────────────────────

test("quickslots: an empty slot, or an item on the cursor, opens the flyout; a plain click does not", function()
    local _, _, M = flyoutInstance("secret_slots")
    local rec, buttons = M.__flyout, M.__slotButtons
    buttons.ChestSlot:__fire("PostClick", "LeftButton", false)
    -- red under: opening the flyout on every click (dropping the cursor / empty-slot condition).
    assertEqual(#rec.clicked, 0, "a click on a filled slot with an empty cursor leaves the flyout shut")
    buttons.LegsSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#rec.clicked, 1, "an empty slot opens the flyout")
    assertTrue(rec.clicked[1] == buttons.LegsSlot.popoutButton, "through the slot's own popout button")
    M.CursorHasItem = function() return true end
    buttons.ChestSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#rec.clicked, 2, "an item on the cursor opens the flyout")
    M.CursorHasItem = function() return false end
    -- The helm's link is a secret: it reads as an empty slot (Q12), so the click opens the flyout.
    buttons.HeadSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(#rec.clicked, 3, "a secret link reads as an empty slot")
    assertEqual(rec.hidden, 0)
end)

test("quickslots: a click on the button the flyout is open on closes it", function()
    local _, NS, M = flyoutInstance("secret_slots")
    local rec, buttons = M.__flyout, M.__slotButtons
    local flyout = M.EquipmentFlyoutFrame
    flyout:Show()
    flyout.button = buttons.LegsSlot
    buttons.LegsSlot:__fire("PreClick", "LeftButton", false)
    assertEqual(QS(NS).CurrentSlot(), "LegsSlot", "PreClick records the slot")
    buttons.LegsSlot:__fire("PostClick", "LeftButton", false)
    -- red under: dropping the open-on-this-button branch (the empty Legs slot would open it again).
    assertEqual(rec.hidden, 1, "the open flyout is closed")
    assertEqual(#rec.clicked, 0, "and not reopened")
    flyout:Show()
    flyout.button = buttons.ChestSlot
    buttons.LegsSlot:__fire("PostClick", "LeftButton", false)
    assertEqual(rec.hidden, 1, "a flyout open on another button is not this click's to close")
    assertEqual(#rec.clicked, 1, "the empty slot opens its own")
end)

test("quickslots: an empty slot opened, closed and clicked again opens again", function()
    local _, _, M = flyoutInstance("secret_slots")
    local legs = M.__slotButtons.LegsSlot
    local flyout = M.EquipmentFlyoutFrame
    legs:__fire("PostClick", "LeftButton", false)
    assertTrue(flyout:IsVisible() and flyout.button == legs, "the first click opens it")
    legs:__fire("PostClick", "LeftButton", false)
    assertFalse(flyout:IsVisible(), "the second closes it")
    -- red under: closing with a bare EquipmentFlyout_Hide (the lock stays set, and this click only
    -- unlocks it: the flyout stays shut).
    assertFalse(legs.popoutButton.flyoutLocked, "the close cleared the popout's lock")
    assertFalse(legs.popoutButton.reversed, "and turned its arrow back")
    legs:__fire("PostClick", "LeftButton", false)
    assertTrue(flyout:IsVisible() and flyout.button == legs, "the third opens it again")
end)

test("quickslots: a lock left set by a flyout closed elsewhere does not swallow the open", function()
    local _, _, M = flyoutInstance("secret_slots")
    local legs = M.__slotButtons.LegsSlot
    legs:__fire("PostClick", "LeftButton", false)
    M.EquipmentFlyout_Hide()                    -- Escape, or another frame closing it: the lock stays
    assertTrue(legs.popoutButton.flyoutLocked)
    legs:__fire("PostClick", "LeftButton", false)
    -- red under: one popout click for the open (it reads the stale lock and only unlocks).
    assertTrue(M.EquipmentFlyoutFrame:IsVisible(), "the click opened the flyout")
    assertTrue(legs.popoutButton.flyoutLocked)
end)

-- ── the location read ────────────────────────────────────────────────────────────────────────────

test("quickslots: a location reads its link through the seam; a secret, void or bogus one is nil", function()
    local inst = unitLoad({ mutate = function(M) M.__gear:load("secret_slots") end })
    local Sort, M = QS(inst.NS).Sort, inst.mocks
    local link, loc = Sort.LocationItemLink(bagLoc(0, 2))
    assertEqual(link, DB.ring_plain_a.link, "a carried item's link")
    assertEqual(loc.bag, 0)
    assertEqual(loc.slot, 2)
    link, loc = Sort.LocationItemLink(PLAYER + 5)
    assertEqual(link, DB.chest_plate.link, "a worn item's link")
    assertEqual(loc.slotID, 5)
    -- red under: reading the container link without the seam (the secret wrapper would come back).
    assertNil((Sort.LocationItemLink(bagLoc(0, 1))), "a secret bag link")
    assertNil((Sort.LocationItemLink(PLAYER + 1)), "a secret worn link")
    assertNil((Sort.LocationItemLink(T.secret(bagLoc(0, 2)))), "a secret location")
    assertNil((Sort.LocationItemLink(1)), "a location the client cannot unpack")
    local base = M.EquipmentManager_GetLocationData
    M.EquipmentManager_GetLocationData = function(location)
        if location == 77 then return { isPlayer = false, isBank = false, isBags = false, slot = 3 } end
        return base(location)
    end
    assertNil((Sort.LocationItemLink(77)), "void storage: neither bags, bank nor player")
end)

-- ── the gates ────────────────────────────────────────────────────────────────────────────────────

-- Every hook body's effect at once: the filter, the sort and the click.
local function hooksActed(M)
    M.__flyout.source = { [PLAYER + 5] = 1 }
    local filtered = flyoutItems(M, 5)[PLAYER + 5] == nil
    local display = flyoutDisplay(M, { bagLoc(0, 2) })
    local sorted = display[#display] == PLACE_IN_BAGS
    local before = #M.__flyout.clicked
    M.__slotButtons.LegsSlot:__fire("PostClick", "LeftButton", false)
    return filtered, sorted, #M.__flyout.clicked > before
end

test("quickslots: every hook body stands down with the addon and comes back with it", function()
    local _, NS, M = flyoutInstance("secret_slots")
    local filtered, sorted, opened = hooksActed(M)
    assertTrue(filtered and sorted and opened, "the hooks act while standing up; nothing below can fail")
    NS.ApplyEnabled(false)
    assertTrue(NS.IsStoodDown())
    filtered, sorted, opened = hooksActed(M)
    -- red under: dropping the `NS.IsStoodDown()` check from the shared gate in modules/QuickSlots.lua.
    assertFalse(filtered, "the filter ran while stood down")
    assertFalse(sorted, "the sort ran while stood down")
    assertFalse(opened, "PostClick opened the flyout while stood down")
    NS.ApplyEnabled(true)
    filtered, sorted, opened = hooksActed(M)
    assertTrue(filtered and sorted and opened, "the hooks act again after the stand-up")
    assertEqual(flyoutHooks(M), 2, "the stand-up did not hook the flyout twice")
end)

test("quickslots: quickSlots.enabled off silences every hook body; on brings them back", function()
    local _, NS, M = flyoutInstance("secret_slots")
    NS.db.profile.quickSlots.enabled = false
    QS(NS).SetEnabled(false)
    local filtered, sorted, opened = hooksActed(M)
    -- red under: dropping the `quickSlots.enabled` read from the shared gate.
    assertFalse(filtered, "the filter ran with quick slots off")
    assertFalse(sorted, "the sort ran with quick slots off")
    assertFalse(opened, "PostClick opened the flyout with quick slots off")
    NS.db.profile.quickSlots.enabled = true
    QS(NS).SetEnabled(true)
    filtered, sorted, opened = hooksActed(M)
    assertTrue(filtered and sorted and opened, "the hooks act again with quick slots on")
end)

test("quickslots: the stand-down owns nothing to tear down: no event, no timer, no frame", function()
    local _, NS, M = flyoutInstance("secret_slots")
    local frames = #M.__shownFrames()
    M.__slotButtons.HeadSlot:__fire("PreClick", "LeftButton", false)
    assertEqual(QS(NS).CurrentSlot(), "HeadSlot")
    QS(NS).Suspend()
    QS(NS).Resume()
    assertEqual(#M.__shownFrames(), frames, "QuickSlots owns no frames (design §7.9)")
    -- red under: dropping `currentSlot = nil` from QuickSlots.Suspend.
    assertNil(QS(NS).CurrentSlot(), "the stand-down forgets the clicked slot")
end)

-- ── the outward drawer (sheet and window feedback design G8) ─────────────────────────────────────
--
-- THE CLIENT STAND-IN. Blizzard's flyout as the drawer meets it, at wow-ui-source@297d7aa: each slot
-- button's popout arrow anchored once, `LEFT` -> slot `RIGHT` (-8, 0), with the unreversed coords
-- (Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1527-1532; the weapons are vertical, :1517-1524);
-- EquipmentFlyout_UpdateItems anchoring `flyout.buttonFrame` `TOPLEFT` -> arrow `TOPRIGHT` + (anchorX,
-- anchorY) with no ClearAllPoints (Blizzard_FrameXML/EquipmentFlyout.lua:331-339); and
-- EquipmentFlyoutPopoutButton_SetReversed's horizontal coord pairs (:633-651). Both functions are
-- globals the instance's hooksecurefunc really post-hooks by name. The window is a recorded fake
-- (`state.shown`, NS.Dock.IsShown): QuickSlots reads it at call time and owns no part of it.

local ARROW_FWD = { 0.15625, 0.5, 0.84375, 0.5, 0.15625, 0, 0.84375, 0 }      -- PaperDollFrame.lua:1527
local ARROW_BACK = { 0.15625, 0, 0.84375, 0, 0.15625, 0.5, 0.84375, 0.5 }     -- EquipmentFlyout.lua:644
local HL_FWD = { 0.15625, 1, 0.84375, 1, 0.15625, 0.5, 0.84375, 0.5 }        -- PaperDollFrame.lua:1528
local HL_BACK = { 0.15625, 0.5, 0.84375, 0.5, 0.15625, 1, 0.84375, 1 }       -- EquipmentFlyout.lua:645
local LEFT_COLUMN = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot",
                      "TabardSlot", "WristSlot" }

-- A region that records its points and counts its writes.
local function region(extra)
    local r = { pts = {}, writes = 0 }
    function r:ClearAllPoints() self.pts = {}; self.writes = self.writes + 1 end
    function r:SetPoint(...) self.pts[#self.pts + 1] = { ... }; self.writes = self.writes + 1 end
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

local function tex()
    local t = {}
    function t:SetTexCoord(...) self.coords = { ... } end
    return t
end

local function sameCoords(got, want, msg)
    assertEqual(table.concat(got or {}, ","), table.concat(want, ","), msg)
end

-- An instance with Blizzard's flyout stand-in and a fake window, the hooks built. `opts.drop` names
-- client functions the instance does not have.
local function drawerInstance(opts)
    opts = opts or {}
    local state = { shown = false }
    local inst = unitLoad({ mutate = function(M)
        local fs = M.PaperDollItemsFrame.flyoutSettings
        fs.anchorX, fs.anchorY, fs.verticalAnchorX, fs.verticalAnchorY = 0, -3, 0, 0
        local flyout = M.CreateFrame("Frame", "EquipmentFlyoutFrame", M.UIParent)
        flyout:Hide()
        flyout.buttonFrame = region()
        for name, b in pairs(M.__slotButtons) do
            local vertical = name == "MainHandSlot" or name == "SecondaryHandSlot"
            local normal, highlight = tex(), tex()
            local popout = region({ GetNormalTexture = function() return normal end,
                                    GetHighlightTexture = function() return highlight end,
                                    GetParent = function() return b end })
            b.verticalFlyout = vertical or nil
            b.popoutButton = popout
            if vertical then
                popout:SetPoint("TOP", b, "BOTTOM", 0, 4)
            else
                popout:SetPoint("LEFT", b, "RIGHT", -8, 0)
                normal:SetTexCoord(unpack(ARROW_FWD)); highlight:SetTexCoord(unpack(HL_FWD))
            end
            popout.writes = 0
        end
        M.EquipmentFlyoutPopoutButton_SetReversed = function(popout, reversed)
            if popout:GetParent().verticalFlyout then return end
            popout:GetNormalTexture():SetTexCoord(unpack(reversed and ARROW_BACK or ARROW_FWD))
            popout:GetHighlightTexture():SetTexCoord(unpack(reversed and HL_BACK or HL_FWD))
        end
        M.EquipmentFlyout_UpdateItems = function()
            local b = flyout.button
            local rel = b.popoutButton or b
            if b.verticalFlyout then
                flyout.buttonFrame:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", fs.verticalAnchorX, fs.verticalAnchorY)
            else
                flyout.buttonFrame:SetPoint("TOPLEFT", rel, "TOPRIGHT", fs.anchorX, fs.anchorY)
            end
        end
        for _, name in ipairs(opts.drop or {}) do M[name] = nil end
        -- hooksecurefunc by name, as the client does it, on the two globals this stand-in defines;
        -- a missing global raises, as it does in the client.
        local base = M.hooksecurefunc
        M.hooksecurefunc = function(a, b, c)
            if type(a) == "string" then
                local orig = rawget(M, a)
                if type(orig) ~= "function" then error("hooksecurefunc(): " .. a .. " is not a function", 2) end
                rawset(M, a, function(...) orig(...); b(...) end)
                M.__hooks[#M.__hooks + 1] = { target = M, name = a }
                return
            end
            return base(a, b, c)
        end
    end })
    local NS, M = inst.NS, inst.mocks
    NS.Dock.IsShown = function() return state.shown end
    QS(NS).Resume()
    return NS, M, state
end

-- The client opening the flyout on `slot`: the arrow locks and reverses, then the items are placed.
local function openFlyout(M, slot)
    local b = M.__slotButtons[slot]
    local flyout = M.EquipmentFlyoutFrame
    flyout.button = b
    flyout:Show()
    b.popoutButton.flyoutLocked = true
    M.EquipmentFlyoutPopoutButton_SetReversed(b.popoutButton, true)
    M.EquipmentFlyout_UpdateItems()
    return flyout.buttonFrame
end

-- The window opening or closing, as Dock's OnShow / OnHide hooks report it.
local function setWindow(NS, state, shown)
    state.shown = shown
    QS(NS).DrawerSync()
end

test("drawer: with the window open a left-column flyout's buttonFrame is anchored TOPRIGHT to the arrow's TOPLEFT", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    -- red under: no EquipmentFlyout_UpdateItems post-hook (Blizzard's TOPLEFT -> TOPRIGHT stays).
    assertEqual(#bf.pts, 1, "the buttonFrame keeps one point, not Blizzard's and ours")
    local p = bf.pts[1]
    assertEqual(p[1], "TOPRIGHT"); assertEqual(p[2], M.__slotButtons.HeadSlot.popoutButton)
    assertEqual(p[3], "TOPLEFT"); assertEqual(p[4], 0); assertEqual(p[5], -3)
end)

test("drawer: with the window open the left-column arrows sit on the slot's left, mirrored", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    for _, slot in ipairs(LEFT_COLUMN) do
        local b = M.__slotButtons[slot]
        local popout = b.popoutButton
        assertEqual(#popout.pts, 1, slot)
        local p = popout.pts[1]
        assertEqual(p[1], "RIGHT", slot); assertEqual(p[2], b, slot); assertEqual(p[3], "LEFT", slot)
        assertEqual(p[4], 8, slot); assertEqual(p[5], 0, slot)
        sameCoords(popout:GetNormalTexture().coords, ARROW_BACK, slot .. ": the arrow points left")
        sameCoords(popout:GetHighlightTexture().coords, HL_BACK, slot)
    end
end)

test("drawer: a right-column flyout is left alone", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local hands = M.__slotButtons.HandsSlot
    assertEqual(hands.popoutButton.writes, 0, "a right-column arrow was moved")
    local bf = openFlyout(M, "HandsSlot")
    assertEqual(#bf.pts, 1)
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][3], "TOPRIGHT")
    assertEqual(bf.writes, 1, "the drawer wrote to a right-column flyout")
    sameCoords(hands.popoutButton:GetNormalTexture().coords, ARROW_BACK, "Blizzard's own reversed arrow")
end)

test("drawer: the weapons' flyout opens down as Blizzard has it", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local bf = openFlyout(M, "MainHandSlot")
    assertEqual(bf.writes, 1)
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][3], "BOTTOMLEFT")
    assertEqual(M.__slotButtons.MainHandSlot.popoutButton.writes, 0, "the drawer moved a weapon's arrow")
end)

test("drawer: a right-column flyout after a left one drops the left one's anchor", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    openFlyout(M, "HeadSlot")
    local bf = openFlyout(M, "HandsSlot")
    -- red under: no restore of a moved buttonFrame (Blizzard's TOPLEFT would join our TOPRIGHT).
    assertEqual(#bf.pts, 1, "two points stretch the flyout")
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][2], M.__slotButtons.HandsSlot.popoutButton)
end)

test("drawer: SetReversed on a left-column arrow mirrors its coords", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local popout = M.__slotButtons.ChestSlot.popoutButton
    M.EquipmentFlyoutPopoutButton_SetReversed(popout, true)
    -- red under: no SetReversed post-hook (Blizzard's reversed coords, pointing right, would stay).
    sameCoords(popout:GetNormalTexture().coords, ARROW_FWD, "reversed and mirrored points right")
    sameCoords(popout:GetHighlightTexture().coords, HL_FWD)
    M.EquipmentFlyoutPopoutButton_SetReversed(popout, false)
    sameCoords(popout:GetNormalTexture().coords, ARROW_BACK, "unreversed and mirrored points left")
    local legs = M.__slotButtons.LegsSlot.popoutButton
    M.EquipmentFlyoutPopoutButton_SetReversed(legs, true)
    sameCoords(legs:GetNormalTexture().coords, ARROW_BACK, "a right-column arrow keeps Blizzard's coords")
end)

test("drawer: with the window closed the flyout keeps Blizzard's anchors", function()
    local _, M = drawerInstance()
    local bf = openFlyout(M, "HeadSlot")
    -- red under: drop the window check from the drawer's gate.
    assertEqual(bf.writes, 1, "the drawer moved the flyout with the window closed")
    assertEqual(bf.pts[1][1], "TOPLEFT")
    local popout = M.__slotButtons.HeadSlot.popoutButton
    assertEqual(popout.writes, 0)
    sameCoords(popout:GetNormalTexture().coords, ARROW_BACK, "Blizzard's own reversed arrow")
end)

test("drawer: closing the window restores the left-column arrows and an open flyout", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    setWindow(NS, state, false)
    for _, slot in ipairs(LEFT_COLUMN) do
        local b = M.__slotButtons[slot]
        local p = b.popoutButton.pts
        assertEqual(#p, 1, slot)
        assertEqual(p[1][1], "LEFT", slot); assertEqual(p[1][2], b, slot); assertEqual(p[1][3], "RIGHT", slot)
        assertEqual(p[1][4], -8, slot); assertEqual(p[1][5], 0, slot)
    end
    local head = M.__slotButtons.HeadSlot.popoutButton
    sameCoords(head:GetNormalTexture().coords, ARROW_BACK, "the open flyout's arrow is Blizzard's reversed one")
    sameCoords(M.__slotButtons.NeckSlot.popoutButton:GetNormalTexture().coords, ARROW_FWD, "a closed one, unreversed")
    assertEqual(#bf.pts, 1)
    assertEqual(bf.pts[1][1], "TOPLEFT"); assertEqual(bf.pts[1][2], head); assertEqual(bf.pts[1][3], "TOPRIGHT")
    assertEqual(bf.pts[1][4], 0); assertEqual(bf.pts[1][5], -3)
end)

test("drawer: stood down nothing is moved", function()
    local NS, M, state = drawerInstance()
    NS.ApplyEnabled(false)
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    M.EquipmentFlyoutPopoutButton_SetReversed(M.__slotButtons.HeadSlot.popoutButton, false)
    assertEqual(bf.writes, 1, "the stood-down drawer moved the flyout")
    for _, slot in ipairs(LEFT_COLUMN) do
        assertEqual(M.__slotButtons[slot].popoutButton.writes, 0, slot)
    end
    sameCoords(M.__slotButtons.HeadSlot.popoutButton:GetNormalTexture().coords, ARROW_FWD)
end)

test("drawer: a stand-down with the window open puts Blizzard's drawer back", function()
    local NS, M, state = drawerInstance()
    setWindow(NS, state, true)
    openFlyout(M, "HeadSlot")
    -- red under: drop the drawer restore from QuickSlots.Suspend.
    NS.ApplyEnabled(false)
    local head = M.__slotButtons.HeadSlot.popoutButton
    assertEqual(head.pts[1][1], "LEFT")
    assertEqual(M.EquipmentFlyoutFrame.buttonFrame.pts[1][1], "TOPLEFT")
end)

test("drawer: in combat lockdown nothing is moved", function()
    local NS, M, state = drawerInstance()
    M.__lockdown = true
    setWindow(NS, state, true)
    local bf = openFlyout(M, "HeadSlot")
    assertEqual(bf.writes, 1, "the drawer moved the flyout in lockdown")
    assertEqual(M.__slotButtons.HeadSlot.popoutButton.writes, 0, "the drawer moved an arrow in lockdown")
end)

test("drawer: a missing Blizzard function installs nothing and errors nothing", function()
    local NS, M, state = drawerInstance({ drop = { "EquipmentFlyout_UpdateItems",
                                                   "EquipmentFlyoutPopoutButton_SetReversed" } })
    -- red under: an unguarded hooksecurefunc by name (the stand-in raises on a missing global).
    for _, h in ipairs(M.__hooks) do
        assertTrue(h.name ~= "EquipmentFlyout_UpdateItems" and h.name ~= "EquipmentFlyoutPopoutButton_SetReversed",
            "hooked a missing function")
    end
    setWindow(NS, state, true)
    setWindow(NS, state, false)
end)
