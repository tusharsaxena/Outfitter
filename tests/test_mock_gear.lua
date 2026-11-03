-- tests/test_mock_gear.lua — the domain mock's fidelity (design §9.2, §9.3; P4.1): the gear half
-- moves items for real under the client's swap, two-hander, unique-equipped, specialty-bag and
-- bag-full rules, its events arrive only when delivered, secret fixtures hand out wrappers, the
-- bank is unreadable while closed and C_EquipmentSet's sets follow their items and survive the
-- zero-sets flake (Q8); the world half's instance, restriction, aura, spec, protected-frame, hook,
-- sheet and tooltip models; and `fake`, the stand-in rule of design §12.
--
-- Every case builds a bare mock from tests/wow_mock.lua (no addon load): what is under test is the
-- client model the later suites stand on, not the addon.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local Mock = assert(loadfile(T.root .. "/tests/wow_mock.lua"))(T.root)
local Items = Mock.fixtures.items.db

local function mock(scenario, overrides)
    local M = Mock.build()
    if scenario then M.__gear:load(scenario, overrides) end
    return M, M.__gear
end

local function keyAt(G, slotName)
    local i = G:equipped(slotName)
    return i and i.key
end

local function bagKey(G, bag, slot)
    local i = G:bagItem(bag, slot)
    return i and i.key
end

-- A raw frame registered for `events`, counting what reaches it.
local function listener(M, events)
    local f, got = M.CreateFrame("Frame"), {}
    for _, e in ipairs(events) do f:RegisterEvent(e) end
    f:SetScript("OnEvent", function(_, event, ...) got[#got + 1] = { event, ... } end)
    return got
end

-- ── fixtures ──────────────────────────────────────────────────────────────────────────────────

test("mock gear: a fixture link is the 12.x shape, zero fields empty, the five tail fields present", function()
    assertEqual(Items.wrist_plate.link,
        "|cnIQ3:|Hitem:212395::::::::80::::3:10353:1520:10255:1:28:2734:::::|h[Vambraces of the Track]|h|r")
    assertTrue(Items.chest_champion.id == Items.chest_hero.id, "two upgrade tracks share one id")
    assertTrue(Items.chest_champion.link ~= Items.chest_hero.link, "and differ in the link")
end)

test("mock gear: the shared instance carries both halves, so the addon loads against them", function()
    assertTrue(T.mocks.__gear ~= nil and T.mocks.__world ~= nil)
    assertEqual(type(T.mocks.C_Container.GetContainerItemLink), "function")
end)

test("mock gear: a scenario places worn and carried items the client APIs answer for", function()
    local M = mock("geared")
    assertEqual(M.GetInventoryItemLink("player", 1), Items.head_plate.link)
    assertEqual(M.C_Container.GetContainerItemLink(0, 1), Items.greatsword.link)
    assertEqual(M.C_Container.GetContainerNumSlots(3), 4, "a bag's size is its bag item's")
    assertEqual(M.GetInventoryItemLink("player", 33), Items.bag_small4.link, "the bag's own slot (31-35)")
    local free, family = M.C_Container.GetContainerNumFreeSlots(0)
    assertEqual(free, 11)
    assertEqual(family, 0)
    assertEqual(select(4, M.C_Item.GetItemInfo(Items.chest_hero.link)), 639)
    assertEqual(M.GetInventorySlotInfo("SecondaryHandSlot"), 17)
    T.assertError(function() M.GetInventorySlotInfo("AmmoSlot") end, "an unknown slot name raises")
end)

-- ── moves ─────────────────────────────────────────────────────────────────────────────────────

test("mock gear: pickup and equip swap for real, recorded in order, events only when delivered", function()
    local M, G = mock("geared")
    local got = listener(M, { "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE", "BAG_UPDATE_DELAYED" })
    M.C_Container.PickupContainerItem(0, 2)
    assertTrue(M.CursorHasItem())
    assertEqual(select(2, M.GetCursorInfo()), Items.ring_unique_a.id)
    M.PickupInventoryItem(11)
    assertEqual(keyAt(G, "Finger0Slot"), "ring_unique_a")
    assertEqual(bagKey(G, 0, 2), "ring_plain_a", "the worn ring went where the new one came from")
    assertFalse(M.CursorHasItem())
    assertEqual(#M.__equipCalls, 2)
    assertEqual(M.__equipCalls[1][1], "PickupContainerItem")
    assertEqual(M.__equipCalls[2][1], "PickupInventoryItem")
    -- red under: fire M.__fire from `queue` in tests/mock_gear.lua instead of queueing.
    assertEqual(#got, 0, "nothing fired before delivery")
    G:deliver()
    assertEqual(got[1][1], "BAG_UPDATE")
    assertEqual(got[#got][1], "BAG_UPDATE_DELAYED", "delayed comes once, last")
end)

test("mock gear: a two-hander empties the off hand into the bags, and full bags refuse it", function()
    local M, G = mock("geared")
    M.C_Container.PickupContainerItem(0, 1)
    M.EquipCursorItem(16)
    assertEqual(keyAt(G, "MainHandSlot"), "greatsword")
    assertNil(G:equipped("SecondaryHandSlot"), "the shield left the off hand")
    assertEqual(select(1, G:find("shield")).key, "shield", "and is in the bags")

    M, G = mock("full_bags")
    M.C_Container.PickupContainerItem(1, 1)
    -- red under: drop the `if not handDest` ERR_INV_FULL refusal in equipFromCursor (tests/mock_gear.lua).
    assertFalse(M.EquipCursorItem(16))
    assertEqual(M.__gearErrors[1], "ERR_INV_FULL")
    assertEqual(keyAt(G, "MainHandSlot"), "sword_1h", "nothing moved")
    assertEqual(keyAt(G, "SecondaryHandSlot"), "shield")
    assertTrue(M.CursorHasItem(), "the refused item stays on the cursor")
    M.ClearCursor()
    assertEqual(bagKey(G, 1, 1), "greatsword", "ClearCursor puts it back")
end)

test("mock gear: Titan's Grip lets a two-hander sit in the off hand; without it the slot refuses", function()
    local M, G = mock("tg_warrior")
    M.C_Container.PickupContainerItem(0, 1)
    M.EquipCursorItem(16)
    assertEqual(keyAt(G, "MainHandSlot"), "sword_1h")
    assertEqual(keyAt(G, "SecondaryHandSlot"), "greataxe", "the off-hand two-hander stays")

    M, G = mock("dual_wield")
    M.C_Container.PickupContainerItem(0, 1)
    -- red under: make `fits` in tests/mock_gear.lua answer true for a two-hander in the off hand.
    assertFalse(M.EquipCursorItem(17))
    assertEqual(M.__gearErrors[1], "ERR_WRONG_SLOT")
    assertEqual(keyAt(G, "SecondaryHandSlot"), "sword_1h_b")
end)

test("mock gear: a unique-equipped category refuses a second wearer, but replacing the first is fine", function()
    local M, G = mock("unique_rings")
    M.C_Container.PickupContainerItem(0, 1)
    -- red under: make breaksUnique in tests/mock_gear.lua return false.
    assertFalse(M.EquipCursorItem(12))
    assertEqual(M.__gearErrors[1], "ERR_ITEM_UNIQUE_EQUIPPABLE")
    assertEqual(keyAt(G, "Finger1Slot"), "ring_plain_a")
    assertTrue(M.EquipCursorItem(11), "into the slot the first signet holds")
    assertEqual(keyAt(G, "Finger0Slot"), "ring_unique_b")
    -- A self-unique item: one copy worn, the second refused.
    M.C_Container.PickupContainerItem(0, 2)
    assertTrue(M.EquipCursorItem(12))
    M.C_Container.PickupContainerItem(0, 3)
    assertFalse(M.EquipCursorItem(11))
    assertEqual(M.__gearErrors[2], "ERR_ITEM_UNIQUE_EQUIPPABLE")
end)

test("mock gear: gear never lands in a herb bag, and a full backpack keeps it on the cursor", function()
    local M, G = mock("specialty_bags")
    local free, family = M.C_Container.GetContainerNumFreeSlots(1)
    assertEqual(free, 23)
    assertEqual(family, 0x0020)
    M.PickupInventoryItem(1)
    -- red under: make `accepts` in tests/mock_gear.lua return true for every bag.
    assertFalse(M.PutItemInBag(31))
    assertEqual(M.__gearErrors[1], "ERR_ITEM_DOESNT_GO_INTO_BAG")
    assertFalse(M.PutItemInBackpack())
    assertEqual(M.__gearErrors[2], "ERR_BAG_FULL")
    M.ClearCursor()
    assertEqual(keyAt(G, "HeadSlot"), "head_plate", "still worn")
    assertTrue(Mock.gear.sharesBit(0x0020, 0x0420))
    assertFalse(Mock.gear.sharesBit(0x0020, 0x0400))
end)

test("mock gear: equipping a BoE binds it, and a warbound item stops being warbound", function()
    local M, G = mock("geared")
    local loc = M.ItemLocation:CreateFromBagAndSlot(0, 3)
    assertFalse(M.C_Item.IsBound(loc))
    M.C_Container.UseContainerItem(0, 3)
    assertEqual(keyAt(G, "LegsSlot"), "boe_legs")
    assertTrue(M.C_Item.IsBound(M.ItemLocation:CreateFromEquipmentSlot(7)))
    local cloak = M.ItemLocation:CreateFromBagAndSlot(1, 1)
    assertTrue(M.C_Item.IsBoundToAccountUntilEquip(cloak))
    M.C_Container.UseContainerItem(1, 1)
    assertFalse(M.C_Item.IsBoundToAccountUntilEquip(M.ItemLocation:CreateFromEquipmentSlot(15)))
end)

-- ── secrets, bank, item info ──────────────────────────────────────────────────────────────────

test("mock gear: a secret fixture's links are fresh wrappers on every read, the rest stay plain", function()
    local M = mock("secret_slots")
    local a, b = M.GetInventoryItemLink("player", 1), M.GetInventoryItemLink("player", 1)
    assertTrue(T.isSecret(a))
    assertFalse(rawequal(a, b), "a fresh wrapper per read")
    assertEqual(T.reveal(a), Items.secret_helm.link)
    assertTrue(T.isSecret(M.C_Container.GetContainerItemLink(0, 1)))
    assertTrue(T.isSecret(M.C_Container.GetContainerItemInfo(0, 1).hyperlink))
    assertTrue(T.isSecret(M.C_TooltipInfo.GetInventoryItem("player", 1).lines[1].leftText))
    assertEqual(M.GetInventoryItemLink("player", 5), Items.chest_plate.link)
end)

test("mock gear: the bank reads empty while closed and opens with the client's events", function()
    local M, G = mock("bank_closed")
    -- red under: drop the `b.bank and not (G.bankOpen ...)` refusal in readable() (tests/mock_gear.lua).
    assertEqual(M.C_Container.GetContainerNumSlots(6), 0)
    assertNil(M.C_Container.GetContainerItemLink(6, 1))
    local got = listener(M, { "BANKFRAME_OPENED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" })
    G:openBank()
    assertEqual(#got, 2)
    assertEqual(got[2][2], M.Enum.PlayerInteractionType.Banker)
    assertEqual(M.C_Container.GetContainerNumSlots(6), 98)
    assertEqual(M.C_Container.GetContainerItemLink(6, 1), Items.legs_plate.link)
    M.C_Container.UseContainerItem(6, 1)
    assertEqual(bagKey(G, 0, 2), "legs_plate", "right-click with the bank open withdraws")
    assertEqual(M.C_Bank.FetchPurchasedBankTabIDs(M.Enum.BankType.Character)[1], 6)
end)

test("mock gear: an uncached item answers nil until GET_ITEM_INFO_RECEIVED; Instant never waits", function()
    local M, G = mock("uncached")
    local link = Items.legs_plate.link
    assertNil(M.C_Item.GetItemInfo(link))
    assertEqual((M.C_Item.GetItemInfoInstant(link)), Items.legs_plate.id)
    local got = listener(M, { "GET_ITEM_INFO_RECEIVED" })
    G:resolve("legs_plate")
    assertEqual(got[1][2], Items.legs_plate.id)
    assertEqual((M.C_Item.GetItemInfo(link)), "Legplates of Setup")
    assertEqual(M.C_Item.GetDetailedItemLevelInfo(Items.chest_champion.link), 626)
end)

-- ── C_EquipmentSet ────────────────────────────────────────────────────────────────────────────

test("mock gear: EM sets follow their items, wear for real, and survive the zero-sets flake", function()
    local M, G = mock("em_sets")
    local EM, LOC = M.C_EquipmentSet, Mock.gear.LOCATION
    assertEqual(#EM.GetEquipmentSetIDs(), 2)
    local locs = EM.GetItemLocations(2)
    assertEqual(locs[16], LOC.PLAYER + LOC.BAGS + 1, "the greatsword in bag 0 slot 1")
    assertEqual(locs[17], 0, "an empty-slot entry")
    assertEqual(locs[1], 1, "an ignored slot")
    local data = M.EquipmentManager_GetLocationData(locs[16])
    assertTrue(data.isBags and data.isPlayer)
    assertEqual(data.bag, 0)
    assertEqual(data.slot, 1)
    assertTrue(EM.UseEquipmentSet(2))
    assertEqual(keyAt(G, "MainHandSlot"), "greatsword")
    assertNil(G:equipped("SecondaryHandSlot"))
    assertEqual(EM.GetItemLocations(2)[16], LOC.PLAYER + 16, "the set followed its item")
    assertTrue(select(4, EM.GetEquipmentSetInfo(2)), "and is now the worn set")
    M.__emFlake = true
    -- red under: drop the `if M.__emFlake then return {} end` in visible() (tests/mock_gear_sets.lua).
    assertEqual(EM.GetNumEquipmentSets(), 0)
    assertNil(EM.GetEquipmentSetInfo(1))
    M.__emFlake = false
    assertEqual(EM.GetEquipmentSetInfo(1), "Tank", "the flake forgot nothing")
    EM.IgnoreSlotForSave(4)
    EM.CreateEquipmentSet("Fresh", 134400)
    local id = EM.GetEquipmentSetID("Fresh")
    assertEqual(EM.GetIgnoredSlots(id)[4], true)
    assertEqual(EM.GetItemIDs(id)[16], Items.greatsword.id, "a new set snapshots what is worn")
end)

-- ── the world half ────────────────────────────────────────────────────────────────────────────

test("mock world: instance info, restriction by name, auras that raise while restricted", function()
    local M = mock()
    local W = M.__world
    W:setInstance{ name = "Warsong Gulch", type = "pvp", instanceID = 2106, maxPlayers = 10, groupSize = 10 }
    local fields = { M.GetInstanceInfo() }
    assertEqual(fields[1], "Warsong Gulch")
    assertEqual(fields[2], "pvp")
    assertEqual(fields[8], 2106)
    assertEqual(select(2, M.IsInInstance()), "pvp")
    assertEqual(M.Enum.AddOnRestrictionType.Combat, 0)
    local aura = T.secret({ name = "Hidden" })
    W:setAuras("player", "HELPFUL", { { name = "Prowl", spellId = 5215 }, aura })
    assertTrue(rawequal(M.C_UnitAuras.GetAuraDataByIndex("player", 2, "HELPFUL"), aura), "a secret entry, untouched")
    assertEqual(M.C_UnitAuras.GetPlayerAuraBySpellID(5215).name, "Prowl")
    W:setRestricted({ [M.Enum.AddOnRestrictionType.Combat] = true })
    assertTrue(M.C_RestrictedActions.IsAddOnRestrictionActive(0))
    assertFalse(M.C_RestrictedActions.IsAddOnRestrictionActive(3))
    -- red under: drop the restrictedAny() raise in guard() in tests/mock_world.lua.
    T.assertError(function() M.C_UnitAuras.GetAuraDataByIndex("player", 1, "HELPFUL") end)
end)

test("mock world: specs answer from the set class, and the base answer stands until one is set", function()
    local M = mock()
    assertEqual((M.GetSpecializationInfo(1)), 250, "the base mock's spec, which the C6 suites pin")
    assertEqual(M.GetNumSpecializations(), 0)
    M = mock("specialty_bags")
    assertEqual(M.__context.classToken, "DRUID")
    assertEqual(M.GetNumSpecializations(), 4)
    local id, name, _, icon = M.GetSpecializationInfo(2)
    assertEqual(id, 103)
    assertEqual(name, "Feral")
    assertEqual(icon, 1002)
    M.__world:setUnit("player", { health = T.secret(40) })
    assertTrue(T.isSecret(M.UnitHealth("player")))
    assertEqual(M.UnitLevel("player"), 80)
end)

test("mock world: a Secure template is protected in combat; a plain frame is not", function()
    local M = mock()
    local secure = M.CreateFrame("Button", nil, M.UIParent, "SecureActionButtonTemplate")
    local plain = M.CreateFrame("Button", nil, M.UIParent)
    local regen = listener(M, { "PLAYER_REGEN_DISABLED" })
    M.__world:setCombat(true)
    assertTrue(M.InCombatLockdown())
    assertEqual(#regen, 1)
    secure:Hide()
    plain:Hide()
    -- red under: drop the InCombatLockdown() branch of protect() in tests/mock_world.lua.
    assertTrue(secure:IsShown(), "blocked")
    assertEqual(M.__blocked[1].method, "Hide")
    assertFalse(plain:IsShown())
    M.__world:setCombat(false)
    secure:SetAttribute("type", "macro")
    secure:Hide()
    assertFalse(secure:IsShown())
    assertEqual(secure:GetAttribute("type"), "macro")
end)

test("mock world: hooksecurefunc hooks the pet journal, and stays a no-op elsewhere", function()
    local M = mock()
    local seen = {}
    M.hooksecurefunc(M.C_PetJournal, "SummonPetByGUID", function(guid) seen[#seen + 1] = guid end)
    M.C_PetJournal.SummonPetByGUID("BattlePet-0-000000000002")
    assertEqual(seen[1], "BattlePet-0-000000000002")
    assertEqual(M.C_PetJournal.GetSummonedPetGUID(), "BattlePet-0-000000000002", "the original ran too")
    local other = { Fn = function() return 1 end }
    M.hooksecurefunc(other, "Fn", function() seen[#seen + 1] = "x" end)
    other.Fn()
    assertEqual(#seen, 1, "an unmodeled table is not hooked")
end)

test("mock world: the paper doll's frames, and a tooltip drawn from an item", function()
    local M = mock("geared")
    local kids = { M.CharacterFrame:GetChildren() }
    assertTrue(rawequal(kids[1], M.PaperDollFrame))
    assertEqual(M.CharacterHeadSlot:GetID(), 1)
    assertEqual(type(M.PaperDollItemsFrame.flyoutSettings), "table")
    local shown = 0
    M.PaperDollFrame:SetScript("OnShow", function() shown = shown + 1 end)
    assertFalse(M.CharacterFrame:IsShown(), "the sheet starts closed")
    M.__world:openCharacter()
    assertEqual(shown, 1)
    M.GameTooltip:SetInventoryItem("player", 1)
    assertEqual(M.GameTooltipTextLeft1:GetText(), "Helm of the Test Bench")
    local r, g, b = M.GameTooltip.TextLeft1:GetTextColor()
    assertEqual(r + g + b > 0, true)
    assertEqual(M.GameTooltipTextLeft2:GetText(), "Soulbound")
    assertEqual(M.GameTooltip:GetPrimaryTooltipInfo().getterName, "GetInventoryItem")
    assertEqual(select(2, M.GameTooltip:GetItem()), Items.head_plate.link)
end)

-- ── the fake rule ─────────────────────────────────────────────────────────────────────────────

test("mock gear: fake records calls, refuses an unlisted member, and restores what was there", function()
    local NS = { Stack = "real" }
    local f, restore = Mock.fake(NS, "Stack", { Remove = true, Top = function() return "o1" end })
    assertTrue(rawequal(NS.Stack, f))
    NS.Stack.Remove("o2", true)
    assertEqual(NS.Stack.Top(), "o1")
    assertEqual(f.__count("Remove"), 1)
    assertEqual(f.__calls[1][2], "o2")
    -- red under: drop the raising __index from fake() in tests/wow_mock.lua.
    T.assertError(function() return NS.Stack.Wear end, "an unexpected member raises")
    restore()
    assertEqual(NS.Stack, "real")
    local empty = {}
    T.assertError(function()
        Mock.fake(empty, "Equip", { Request = true }, function(e) e.Request(); error("boom") end)
    end)
    assertNil(rawget(empty, "Equip"), "restored after the body raised")
end)
