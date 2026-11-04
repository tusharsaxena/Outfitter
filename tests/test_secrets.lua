-- tests/test_secrets.lua — the secret-value seam (design §2.2, BP §6.9; P3 C6 part): NS.Secrets'
-- conversions with the secrets system absent and present, the bounded walk, NS.Compat's guards on
-- both arms (the library's and the library-absent stub), the C6 unit/CVar/addon/spec reads answering
-- plain-or-nil, the P4.2 accessors (design §5.13: item, container, cooldown, location, tooltip, pet,
-- hook, Equipment Manager, title, bank, cursor, macro-icon and Pawn reads, each plain-or-nil, each with
-- its no-answer value when the API is absent), and the seam scan: no securable client API is named
-- outside the compat family, core/Secrets.lua and modules/States.lua. The states part lives in
-- tests/test_secrets_states.lua (P4.14: PlayerIsFull, the aura scan, prevMana). The engine cases,
-- final at P4.27, run on the whole login: a secret bag or worn link is an empty slot, a secret
-- UnitLevel lets an item through, the tooltip, compare, quick-slot and `/of iteminfo` paths refuse a
-- secret link quietly, and the Equip count is balanced after a raise.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local S, C = NS.Secrets, NS.Compat

-- Run `fn` with the client's `issecretvalue` installed (the kit's simulator) and any mock overrides
-- in `over`, restoring both however `fn` leaves.
local function with(over, fn)
    local restoreSecret = T.installSecretValue()
    local saved = {}
    for k, v in pairs(over or {}) do
        saved[k] = { v = rawget(T.mocks, k) }
        T.mocks[k] = v
    end
    local ok, err = pcall(fn)
    for k, box in pairs(saved) do T.mocks[k] = box.v end
    restoreSecret()
    if not ok then error(err, 0) end
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

test("secrets: NS.Secrets publishes the §2.2 surface and the NS aliases", function()
    for _, name in ipairs({ "IsSecret", "CanAccess", "IsSafeKey", "IsSealed", "Unsecret", "PlainNumber",
                            "PlainString", "UnsecretNumber", "PlainTruth", "PlainEquals",
                            "CanAccessTable", "SafeIterate" }) do
        assertEqual(type(S[name]), "function", "NS.Secrets." .. name)
    end
    assertEqual(S.ITERATION_LIMIT, 512)
    assertEqual(NS.IsSecret, S.IsSecret)
    assertEqual(NS.Unsecret, S.Unsecret)
    assertEqual(NS.SafeNumber, S.UnsecretNumber)
end)

test("secrets: the guards are NS.Compat's, routed through LibKa0s-Compat-1.0 when it loads", function()
    local lib = T.mocks.LibStub("LibKa0s-Compat-1.0", true)
    assertTrue(lib ~= nil, "the vendored Compat major registered")
    assertEqual(C.IsSecret, lib.IsSecret)
    assertEqual(C.CanAccess, lib.CanAccess)
    assertEqual(C.IsSafeKey, lib.IsSafeKey)
    assertEqual(C.GetSpecialization, lib.GetSpecialization)
    assertEqual(C.GetSpecializationInfo, lib.GetSpecializationInfo)
    assertEqual(S.IsSecret, C.IsSecret)
    assertEqual(S.CanAccess, C.CanAccess)
    assertEqual(S.IsSafeKey, C.IsSafeKey)
end)

-- ── conversions, secrets system absent ────────────────────────────────────────────────────────

test("secrets: without the secrets system every value is plain", function()
    assertFalse(S.IsSecret(5))
    assertFalse(S.IsSealed("x"))
    assertFalse(S.IsSealed(nil), "nil is absent, not sealed")
    assertEqual(S.Unsecret(7), 7)
    assertEqual(S.Unsecret("link"), "link")
    assertEqual(S.PlainNumber(3.5), 3.5)
    assertNil(S.PlainNumber("3"), "a string is not a number")
    assertNil(S.PlainNumber(nil))
    assertEqual(S.PlainString("x"), "x")
    assertNil(S.PlainString(4), "a number is not a string")
    assertEqual(S.UnsecretNumber(0, 9), 0, "0 is a plain number, not a miss")
    assertEqual(S.UnsecretNumber(nil, 9), 9)
    assertEqual(S.UnsecretNumber("4", 9), 9)
    assertNil(S.UnsecretNumber(nil), "the fallback defaults to nil")
    assertTrue(S.IsSafeKey("k"))
    assertFalse(S.IsSafeKey(nil), "nil is never a key")
    assertTrue(S.PlainEquals(2, 2))
    assertFalse(S.PlainEquals(2, 3))
end)

test("secrets: PlainTruth answers true, false or nil, reading 1 and 0 as the old flags", function()
    assertEqual(S.PlainTruth(true), true)
    assertEqual(S.PlainTruth(1), true)
    assertEqual(S.PlainTruth(false), false)
    assertEqual(S.PlainTruth(0), false)
    assertNil(S.PlainTruth(nil))
    assertNil(S.PlainTruth("yes"), "any other type is no claim")
end)

-- ── conversions, secrets system present ───────────────────────────────────────────────────────

test("secrets: a secret is sealed and every conversion refuses it without inspecting it", function()
    with(nil, function()
        local s = T.secret(42)
        assertTrue(S.IsSecret(s))
        assertTrue(NS.IsSecret(s), "the alias answers the same")
        assertTrue(S.IsSealed(s))
        assertFalse(S.CanAccess(s), "no canaccessvalue: accessible unless known secret")
        assertFalse(S.IsSafeKey(s))
        assertNil(S.Unsecret(s))
        assertNil(NS.Unsecret(s))
        assertNil(S.PlainNumber(s))
        assertNil(S.PlainString(T.secret("|cffffffff|Hitem:1|h[x]|h|r")))
        assertEqual(S.UnsecretNumber(s, 0), 0)
        assertEqual(NS.SafeNumber(s, -1), -1)
        assertNil(S.PlainTruth(T.secret(true)), "a secret boolean is never truth-tested")
        assertFalse(S.PlainEquals(s, 42))
        assertFalse(S.PlainEquals(42, s))
        assertFalse(S.PlainEquals(s, T.secret(42)), "two secrets never reach the trapped ==")
        -- A plain value is untouched with the system installed.
        assertEqual(S.PlainNumber(42), 42)
        assertFalse(S.IsSecret(42))
    end)
end)

test("secrets: canaccessvalue decides access where the client has it", function()
    with({ canaccessvalue = function(v) return v ~= "hidden" end }, function()
        assertTrue(S.CanAccess("shown"))
        assertFalse(S.CanAccess("hidden"))
        assertTrue(S.IsSealed("hidden"), "inaccessible is sealed even when not secret")
        assertNil(S.PlainString("hidden"))
        assertEqual(S.PlainString("shown"), "shown")
    end)
end)

-- ── the bounded walk ──────────────────────────────────────────────────────────────────────────

local function collect(t, max)
    local out = {}
    for i, e in S.SafeIterate(t, max) do out[#out + 1] = { i, e } end
    return out
end

test("secrets: SafeIterate walks in order and stops at the first nil", function()
    local got = collect({ "a", "b", nil, "d" })
    assertEqual(#got, 2)
    assertEqual(got[1][1], 1)
    assertEqual(got[1][2], "a")
    assertEqual(got[2][2], "b")
    assertEqual(#collect({}), 0)
end)

test("secrets: SafeIterate is bounded at max, and at 512 by default", function()
    local big = {}
    for i = 1, 600 do big[i] = i end
    assertEqual(#collect(big), 512)
    assertEqual(#collect(big, 100), 100)
    assertEqual(#collect(big, 0), 512, "a non-positive max takes the default")
    assertEqual(#collect(big, "9"), 512, "a non-number max takes the default")
end)

test("secrets: SafeIterate never measures the table with #", function()
    -- A proxy whose entries live behind __index: `#` on it answers 0 in Lua, so a walk that measured
    -- the table first would yield nothing.
    local backing = { "x", "y", "z" }
    local proxy = setmetatable({}, { __index = backing })
    assertEqual(#proxy, 0)
    assertEqual(#collect(proxy), 3)
end)

test("secrets: SafeIterate yields secret entries uninspected and refuses unreadable tables", function()
    with({ canaccesstable = function(t) return not t.locked end }, function()
        local s = T.secret(7)
        local got = collect({ s, 2 })
        assertEqual(#got, 2, "a secret entry is not the end of the list")
        assertTrue(T.isSecret(got[1][2]), "the entry is handed over as it came")
        assertEqual(#collect({ 1, 2, locked = true }), 0, "an inaccessible table yields nothing")
    end)
    assertEqual(#collect(nil), 0)
    assertEqual(#collect("not a table"), 0)
end)

test("secrets: issecrettable is the CanAccessTable rung without canaccesstable", function()
    with({ issecrettable = function(t) return t.sealed == true end }, function()
        assertFalse(S.CanAccessTable({ sealed = true }))
        assertTrue(S.CanAccessTable({}))
    end)
    assertTrue(S.CanAccessTable({}), "with neither global every table is readable")
    assertFalse(S.CanAccessTable(5), "a non-table is never readable")
end)

-- ── the library-absent arm ────────────────────────────────────────────────────────────────────

test("secrets: without LibKa0s the Compat stubs still detect a secret", function()
    -- The guard arm is the documented duplication: "the library is missing" is not "the client has
    -- no secrets system", so the stub must answer IsSecret -> true for a real secret.
    local inst = T.load({ libFiles = {}, init = false })
    local lib = T.mocks.LibStub("LibKa0s-Compat-1.0", true)
    assertTrue(inst.NS.Compat.IsSecret ~= lib.IsSecret, "the stub, not the library's member")
    with(nil, function()
        local s = T.secret(1)
        assertTrue(inst.NS.Secrets.IsSecret(s))
        assertFalse(inst.NS.Secrets.CanAccess(s))
        assertFalse(inst.NS.Secrets.IsSafeKey(s))
        assertNil(inst.NS.Secrets.PlainNumber(s))
        assertFalse(inst.NS.Secrets.IsSecret(1))
    end)
    assertFalse(inst.NS.Compat.IsSecret(T.secret(1)), "no client detector: nothing is secret")
end)

test("secrets: the library-absent spec stubs walk C_SpecializationInfo, then the globals", function()
    local inst = T.load({ libFiles = {}, init = false })
    local Cs = inst.NS.Compat
    assertEqual(Cs.GetSpecialization(), 1, "the bare global rung")
    assertEqual((Cs.GetSpecializationInfo(1)), 250)
    assertNil(Cs.GetSpecializationInfo(nil), "no index, no client call")
    inst.mocks.C_SpecializationInfo = {
        GetSpecialization = function() return 3 end,
        GetSpecializationInfo = function(i) return 260 + i end,
    }
    assertEqual(Cs.GetSpecialization(), 3, "the namespaced rung, seen at call time")
    assertEqual((Cs.GetSpecializationInfo(2)), 262)
    inst.mocks.C_SpecializationInfo, inst.mocks.GetSpecialization = nil, false
    assertNil(Cs.GetSpecialization(), "no rung: nil")
end)

-- ── the C6 reads, plain-or-nil ────────────────────────────────────────────────────────────────

test("compat: the unit reads answer plain values", function()
    with({ UnitFactionGroup = function() return "Horde", "Horde (localized)" end,
           UnitLevel = function(unit) return unit == "player" and 80 or 1 end,
           UnitIsDeadOrGhost = function() return false end }, function()
        assertEqual(C.PlayerClass(), T.mocks.__context.classToken)
        assertEqual(C.PlayerFaction(), "Horde", "UnitFactionGroup's FIRST return (H10)")
        assertEqual(C.UnitLevel(), 80, "defaults to the player")
        assertEqual(C.UnitLevel("target"), 1)
        assertEqual(C.IsDeadOrGhost(), false)
        assertEqual(C.InCombatLockdown(), false)
        assertEqual(C.PlayerSpecID(), 250)
    end)
end)

test("compat: a secret read leaves Compat as nil, never as the secret", function()
    with({ UnitFactionGroup = function() return T.secret("Horde") end,
           UnitLevel = function() return T.secret(80) end,
           UnitIsDeadOrGhost = function() return T.secret(true) end,
           UnitClass = function() return "Warrior", T.secret("WARRIOR") end,
           GetCVar = function() return T.secret("1") end,
           GetSpecialization = function() return T.secret(1) end }, function()
        assertNil(C.PlayerFaction())
        assertNil(C.UnitLevel(), "a secret level reads as unknown: the filters let the item through")
        assertNil(C.IsDeadOrGhost())
        assertNil(C.PlayerClass())
        assertNil(C.GetCVar("Sound_EnableSFX"), "a secret CVar: the SFX mute is skipped")
        assertNil(C.PlayerSpecID())
    end)
end)

test("compat: an absent API answers its no-answer value", function()
    with({ UnitFactionGroup = false, UnitLevel = false, UnitIsDeadOrGhost = false, GetCVar = false,
           SetCVar = false, GetNumSpecializations = false }, function()
        -- `false` stands for "absent" here: the mock's __index would otherwise fall through to it.
        assertNil(C.UnitLevel())
        assertNil(C.PlayerFaction())
        assertNil(C.IsDeadOrGhost())
        assertNil(C.GetCVar("x"))
        assertFalse(C.SetCVar("x", "1"))
        assertEqual(C.NumSpecializations(), 0)
    end)
end)

test("compat: CVars, the clock, the spec count and other addons", function()
    local written = {}
    with({ GetCVar = function(name) return name == "Sound_EnableSFX" and "1" or nil end,
           SetCVar = function(name, value) written[name] = value end,
           GetNumSpecializations = function() return 3 end,
           GetTime = function() return 12.5 end }, function()
        assertEqual(C.GetCVar("Sound_EnableSFX"), "1")
        assertNil(C.GetCVar("unknownCVar"))
        assertNil(C.GetCVar(nil))
        assertTrue(C.SetCVar("Sound_EnableSFX", "0"))
        assertEqual(written.Sound_EnableSFX, "0")
        assertEqual(C.NumSpecializations(), 3)
        assertEqual(C.GetTime(), 12.5)
        assertEqual(C.IsAddOnLoaded("OutfitterReborn"), true)
        assertEqual(C.IsAddOnLoaded("Pawn"), false, "the mock loads no other addon")
        assertEqual(C.IsAddOnLoaded(nil), false)
    end)
    with({ C_AddOns = { IsAddOnLoaded = function(name) return name == "Pawn", name == "Pawn" end } }, function()
        assertEqual(C.IsAddOnLoaded("Pawn"), true)
        assertEqual(C.IsAddOnLoaded("WeightsWatcher"), false)
    end)
end)

-- ── the P4.2 accessors, plain-or-nil (design §5.13) ──────────────────────────────────────────

local ACCESSORS = {
    "ContainerItemLink", "InventoryItemLink", "InventoryItemID", "InventorySlotID", "ItemInfo", "ItemInfoInstant",
    "DetailedItemLevel", "ItemStats", "ItemIcon", "ItemSpell", "ItemFamily", "ItemUpgradeInfo",
    "ContainerItemCooldown", "InventoryItemCooldown", "ItemUniqueness", "IsBound", "IsWarboundUntilEquip",
    "CanUseItem", "CanUpgradeItem", "AzeritePowers", "TooltipLines", "TooltipInventoryUnit", "SummonedPetGUID",
    "PetGUIDByName", "PetGUIDBySpecies", "SummonPet", "HookPetSummon", "HookCompare", "EMSetIDs", "EMSetInfo",
    "EMLocations", "EMIgnoredSlots", "EMLocation", "FlyoutLocationData", "EMCreateSet", "EMSaveSet",
    "EMModifySet", "EMDeleteSet", "EMSetID", "EMNumSets", "EMMaxSets", "EMClearIgnored", "EMIgnoreSlot",
    "KnownTitles", "SetCurrentTitle", "BankBagIDs", "IsBankerInteraction", "ContainerNumSlots",
    "ContainerNumFreeSlots", "ContainerIDToInventoryID", "LastEquippedBagID", "PickupContainerItem", "PickupInventoryItem",
    "PickupItemLocation", "UseContainerItem", "ShowContainerSellCursor", "EquipCursorItem", "ClearCursor",
    "MacroIcons", "PawnVisibleScales", "PawnItemValue", "CanDualWield", "BitAnd",
}

-- The client's ItemLocation mixin, reduced to the two constructors Compat calls: `b`/`s` for a bag
-- slot, `e` for an equipment slot.
local FakeItemLocation = {
    CreateFromBagAndSlot = function(_, bag, slot) return { b = bag, s = slot } end,
    CreateFromEquipmentSlot = function(_, slotID) return { e = slotID } end,
}

test("compat: NS.Compat publishes every §5.13 accessor", function()
    for _, name in ipairs(ACCESSORS) do assertEqual(type(C[name]), "function", "NS.Compat." .. name) end
end)

test("compat: the item and slot reads pass plain answers through", function()
    local LINK = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
    with({
        C_Container = { GetContainerItemLink = function(bag, slot) return bag == 0 and slot == 3 and LINK or nil end },
        GetInventoryItemLink = function(unit, id) return unit == "player" and id == 16 and LINK or nil end,
        GetInventoryItemID = function(unit, id) return unit == "player" and id == 16 and 19019 or nil end,
        GetInventorySlotInfo = function(name)
            if name ~= "MainHandSlot" then error("Invalid inventory slot") end
            return 16, 135349
        end,
        C_Item = {
            GetItemInfo = function()
                return "Thunderfury", LINK, 5, 80, 60, "Weapon", "Swords", 1, "INVTYPE_WEAPON", 135349, 0, 2, 7, 1
            end,
            GetItemInfoInstant = function() return 19019, "Weapon", "Swords", "INVTYPE_WEAPON", 135349, 2, 7 end,
            GetDetailedItemLevelInfo = function() return 82, nil, 80 end,
            GetItemStats = function() return { ITEM_MOD_AGILITY_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 8 } end,
            GetItemIconByID = function() return 135349 end,
            GetItemSpell = function() return "Thunderfury", 21992 end,
            GetItemFamily = function() return 0 end,
            GetItemUpgradeInfo = function()
                return { trackStringID = 970, maxItemLevel = 639, currentLevel = 2, maxLevel = 8, trackString = "Hero" }
            end,
        },
    }, function()
        assertEqual(C.ContainerItemLink(0, 3), LINK)
        assertNil(C.ContainerItemLink(0, 4), "an empty slot reads nil")
        assertEqual(C.InventoryItemLink(16), LINK)
        assertEqual(C.InventoryItemID(16), 19019)
        assertEqual(C.InventorySlotID("MainHandSlot"), 16)
        assertNil(C.InventorySlotID("NoSuchSlot"), "the client raises on an unknown name; Compat answers nil")
        local name, quality, level, minLevel, bindType = C.ItemInfo(LINK)
        assertEqual(table.concat({ name, quality, level, minLevel, bindType }, ","), "Thunderfury,5,80,60,1")
        local id, invType, icon, classID, subclassID = C.ItemInfoInstant(19019)
        assertEqual(table.concat({ id, invType, icon, classID, subclassID }, ","), "19019,INVTYPE_WEAPON,135349,2,7")
        assertEqual(C.DetailedItemLevel(LINK), 82, "the actual level, the first return")
        assertEqual(C.ItemStats(LINK).ITEM_MOD_STAMINA_SHORT, 8)
        assertEqual(C.ItemIcon(19019), 135349)
        local spell, spellID = C.ItemSpell(LINK)
        assertEqual(spell, "Thunderfury")
        assertEqual(spellID, 21992)
        assertEqual(C.ItemFamily(LINK), 0)
        local up = C.ItemUpgradeInfo(LINK)
        assertEqual(table.concat({ up.trackStringID, up.maxItemLevel, up.currentLevel, up.maxLevel }, ","), "970,639,2,8")
        assertNil(up.trackString, "the localized track name is not copied (INV §3.11)")
    end)
end)

test("compat: cooldowns answer plain numbers and a normalized enabled flag", function()
    with({ C_Container = { GetContainerItemCooldown = function() return 100, 30, 1 end },
           GetInventoryItemCooldown = function(_, id) return 0, 0, id == 13 and true or 0 end }, function()
        local start, duration, enabled = C.ContainerItemCooldown(0, 1)
        assertEqual(start, 100)
        assertEqual(duration, 30)
        assertEqual(enabled, true, "1 is enabled (B19)")
        assertEqual(select(3, C.InventoryItemCooldown(13)), true)
        assertEqual(select(3, C.InventoryItemCooldown(14)), false, "0 is disabled, not a truthy number")
    end)
end)

test("compat: a secret item read leaves Compat as nil, never as the secret", function()
    local asked = 0
    local function secretly(v) return function() asked = asked + 1 return T.secret(v) end end
    with({
        C_Container = { GetContainerItemLink = secretly("link"),
                        GetContainerItemCooldown = function() return T.secret(1), T.secret(30), T.secret(true) end },
        GetInventoryItemLink = secretly("link"),
        GetInventoryItemID = secretly(5),
        C_Item = {
            GetItemInfo = function()
                return T.secret("n"), nil, T.secret(4), T.secret(80), T.secret(70), nil, nil, nil, nil, nil, nil, nil,
                    nil, T.secret(2)
            end,
            GetDetailedItemLevelInfo = secretly(80),
            GetItemStats = function() return { ITEM_MOD_STAMINA_SHORT = T.secret(9), ITEM_MOD_AGILITY_SHORT = 3 } end,
            GetItemSpell = function() return T.secret("Use"), T.secret(1) end,
            GetItemFamily = secretly(8),
            GetItemUpgradeInfo = function() return T.secret({}) end,
        },
    }, function()
        -- red under: return the client's answer from Compat.ContainerItemLink without NS.Secrets.PlainString
        assertNil(C.ContainerItemLink(0, 1), "a secret link reads as an empty slot (Q12)")
        assertNil(C.InventoryItemLink(1))
        assertNil(C.InventoryItemID(1))
        local name, quality, level, minLevel, bindType = C.ItemInfo("link")
        assertTrue(name == nil and quality == nil and level == nil and minLevel == nil and bindType == nil)
        assertNil(C.DetailedItemLevel("link"))
        local stats = C.ItemStats("link")
        assertNil(stats.ITEM_MOD_STAMINA_SHORT, "a secret stat is dropped")
        assertEqual(stats.ITEM_MOD_AGILITY_SHORT, 3, "and its plain neighbors kept")
        assertNil((C.ItemSpell("link")))
        assertNil(C.ItemFamily("link"))
        assertNil(C.ItemUpgradeInfo("link"), "a secret table is never indexed")
        local start, duration, enabled = C.ContainerItemCooldown(0, 1)
        assertTrue(start == nil and duration == nil and enabled == nil, "the caller takes its 30 s floor")
        local before = asked
        assertNil(C.DetailedItemLevel(T.secret("link")))
        assertEqual(asked, before, "a secret link is refused before the client is asked")
    end)
end)

test("compat: with the client API absent every accessor answers its no-answer value", function()
    local absent = {}
    for _, k in ipairs({ "C_Container", "C_Item", "C_ItemUpgrade", "C_EquipmentSet", "C_PetJournal", "C_TooltipInfo",
                         "C_AzeriteEmpoweredItem", "C_PlayerInfo", "GetInventoryItemLink", "GetInventoryItemID",
                         "GetInventorySlotInfo", "GetInventoryItemCooldown", "PickupInventoryItem", "EquipCursorItem",
                         "ClearCursor", "SetCurrentTitle", "GetMacroIcons", "GetMacroItemIcons",
                         "EquipmentManager_GetLocationData", "PawnGetItemData", "PawnGetAllScales", "GetNumTitles",
                         "hooksecurefunc", "ItemLocation", "CanDualWield", "Enum", "MAX_EQUIPMENT_SETS_PER_PLAYER",
                         "NUM_TOTAL_EQUIPPED_BAG_SLOTS", "IsFlying" }) do
        absent[k] = false   -- `false` stands for absent: the mock's __index would fall through to nil
    end
    local BAG, INV, fn = { bag = 0, slot = 1 }, { slotID = 16 }, function() end
    local NIL = { { "ContainerItemLink", 0, 1 }, { "InventoryItemLink", 16 }, { "InventoryItemID", 16 },
        { "InventorySlotID", "HeadSlot" }, { "ItemInfo", "link" }, { "ItemInfoInstant", 1 }, { "DetailedItemLevel", "l" },
        { "ItemStats", "l" }, { "ItemIcon", 1 }, { "ItemSpell", "l" }, { "ItemFamily", "l" }, { "ItemUpgradeInfo", "l" },
        { "ContainerItemCooldown", 0, 1 }, { "InventoryItemCooldown", 13 }, { "ItemUniqueness", 1 }, { "IsBound", BAG },
        { "IsWarboundUntilEquip", INV }, { "CanUseItem", 1 }, { "CanUpgradeItem", INV }, { "AzeritePowers", INV },
        { "SummonedPetGUID" }, { "PetGUIDByName", "pierre" }, { "PetGUIDBySpecies", 1 }, { "EMSetInfo", 1 },
        { "EMLocation", 1 }, { "FlyoutLocationData", 1 }, { "EMSetID", "Tank" }, { "ContainerIDToInventoryID", 1 },
        { "PawnItemValue", "link", "Alpha" }, { "LastEquippedBagID" } }
    local FALSE = { { "SummonPet", "g" }, { "HookPetSummon", fn }, { "HookCompare", fn }, { "EMCreateSet", "n", 1 },
        { "EMSaveSet", 1, 1 }, { "EMModifySet", 1, "n", 1 }, { "EMDeleteSet", 1 }, { "EMClearIgnored" },
        { "EMIgnoreSlot", 1, true }, { "SetCurrentTitle", 1 }, { "IsBankerInteraction", 8 },
        { "PickupContainerItem", 0, 1 }, { "PickupInventoryItem", 16 }, { "PickupItemLocation", BAG },
        { "UseContainerItem", 0, 1 }, { "ShowContainerSellCursor", 0, 1 }, { "EquipCursorItem", 16 },
        { "ClearCursor" }, { "CanDualWield" }, { "IsFlying" } }
    local EMPTY = { { "TooltipLines", BAG }, { "EMSetIDs" }, { "EMLocations", 1 }, { "EMIgnoredSlots", 1 },
        { "KnownTitles" }, { "BankBagIDs" }, { "MacroIcons", "item" }, { "PawnVisibleScales" } }
    with(absent, function()
        for _, row in ipairs(NIL) do assertNil((C[row[1]](unpack(row, 2))), row[1]) end
        for _, row in ipairs(FALSE) do assertEqual(C[row[1]](unpack(row, 2)), false, row[1]) end
        for _, row in ipairs(EMPTY) do
            local got = C[row[1]](unpack(row, 2))
            assertEqual(type(got), "table", row[1])
            assertNil(next(got), row[1] .. " is empty")
        end
        assertEqual(C.EMNumSets(), 0)
        assertEqual(C.EMMaxSets(), 10, "the client's long-standing cap when the constant is missing")
        assertEqual(C.ContainerNumSlots(0), 0)
        assertEqual(C.ContainerNumFreeSlots(0), 0)
    end)
end)

test("compat: LastEquippedBagID passes the plain constant through and refuses a secret", function()
    with({ NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5 }, function() assertEqual(C.LastEquippedBagID(), 5) end)
    -- red under: `return NUM_TOTAL_EQUIPPED_BAG_SLOTS` (the secret leaves the seam)
    with({ NUM_TOTAL_EQUIPPED_BAG_SLOTS = T.secret(5) }, function() assertNil(C.LastEquippedBagID()) end)
end)

test("compat: location reads build the client's ItemLocation; a raise or a secret reads as unknown", function()
    with({ ItemLocation = FakeItemLocation,
           C_Item = { IsBound = function(l) return l.b == 0 and l.s == 2 end,
                      IsBoundToAccountUntilEquip = function(l)
                          if l.e then error("invalid location") end
                          return T.secret(true)
                      end,
                      DoesItemExist = function(l) return l.e ~= nil end },
           C_ItemUpgrade = { CanUpgradeItem = function(l) return l.e == 16 end },
           C_PlayerInfo = { CanUseItem = function(id)
               if id == 1 then error("no item") end
               return id == 2
           end } }, function()
        assertEqual(C.IsBound({ bag = 0, slot = 2 }), true)
        assertEqual(C.IsBound({ slotID = 5 }), false)
        assertNil(C.IsWarboundUntilEquip({ bag = 1, slot = 1 }), "a secret answer is unknown")
        assertNil(C.IsWarboundUntilEquip({ slotID = 1 }), "a raising client call is unknown")
        assertNil(C.IsBound({}), "a location of neither shape is unknown")
        assertNil(C.IsBound({ bag = T.secret(0), slot = 1 }), "a secret coordinate is no location")
        assertEqual(C.CanUpgradeItem({ slotID = 16 }), true)
        assertEqual(C.CanUpgradeItem({ slotID = 15 }), false)
        assertNil(C.CanUpgradeItem({ bag = 0, slot = 1 }), "no item there: unknown, not false")
        assertEqual(C.CanUseItem(2), true)
        assertEqual(C.CanUseItem(3), false)
        assertNil(C.CanUseItem(1))
    end)
end)

test("compat: AzeritePowers lists the selected powers sorted, and nil off azerite gear", function()
    with({ ItemLocation = FakeItemLocation,
           C_AzeriteEmpoweredItem = {
               IsAzeriteEmpoweredItem = function(l) return l.e == 1 end,
               GetAllTierInfo = function()
                   return { { azeritePowerIDs = { 30, 10 } }, { azeritePowerIDs = { T.secret(5), 20 } } }
               end,
               IsPowerSelected = function(_, id) return id ~= 20 end } }, function()
        assertEqual(table.concat(C.AzeritePowers({ slotID = 1 }), ":"), "10:30", "a secret power id is skipped")
        assertNil(C.AzeritePowers({ slotID = 3 }))
    end)
    -- O17: a 12.x client that dropped or changed a member reads as unknown, never raises.
    with({ ItemLocation = FakeItemLocation,
           C_AzeriteEmpoweredItem = {
               IsAzeriteEmpoweredItem = function() return true end,
               GetAllTierInfo = function() error("GetAllTierInfo changed") end } }, function()
        -- red under: call api.GetAllTierInfo without pcall in Compat.AzeritePowers.
        assertNil(C.AzeritePowers({ slotID = 1 }), "a raising GetAllTierInfo is unknown")
    end)
    with({ ItemLocation = FakeItemLocation,
           C_AzeriteEmpoweredItem = {
               IsAzeriteEmpoweredItem = function() return true end,
               GetAllTierInfo = function() return { { azeritePowerIDs = { 30, 10 } } } end,
               IsPowerSelected = function(_, id) if id == 30 then error("changed") end return true end } }, function()
        -- red under: call api.IsPowerSelected without pcall in selectedPowers (core/Compat.lua).
        assertEqual(table.concat(C.AzeritePowers({ slotID = 1 }), ":"), "10", "a raising power is left out")
    end)
    with({ ItemLocation = FakeItemLocation,
           C_AzeriteEmpoweredItem = { IsAzeriteEmpoweredItem = function() return true end } }, function()
        assertNil(C.AzeritePowers({ slotID = 1 }), "a missing GetAllTierInfo is unknown")
    end)
end)

test("compat: ItemUniqueness answers a plain record, or nil when unreadable", function()
    with({ C_Item = { GetItemUniquenessByID = function(id)
        if id == 1 then return true, "Rings", 2, 77 end
        if id == 2 then return false end
        if id == 3 then return T.secret(true) end
        error("unknown item")
    end } }, function()
        local u = C.ItemUniqueness(1)
        assertEqual(table.concat({ tostring(u.unique), u.categoryID, u.count }, ","), "true,77,2")
        assertEqual(C.ItemUniqueness(2).unique, false)
        assertNil(C.ItemUniqueness(3), "a secret flag")
        assertNil(C.ItemUniqueness(4), "a raising client call (O17: the shape is unconfirmed)")
        assertNil(C.ItemUniqueness(T.secret(1)))
    end)
end)

test("compat: TooltipLines routes by location and drops what it cannot read", function()
    local function data(...) return { lines = { ... } } end
    with({ C_TooltipInfo = {
        GetBagItem = function()
            return data({ leftText = "Soulbound", leftColor = { r = 1, g = 1, b = 1 } },
                        { leftText = T.secret("Unique") },
                        { leftText = "Requires Level 90", leftColor = { r = T.secret(1), g = 0.1, b = 0.1 } })
        end,
        GetInventoryItem = function(unit, id) return unit == "player" and data({ leftText = "Head" .. id }) or nil end,
        GetHyperlink = function() return T.secret({}) end } }, function()
        local lines = C.TooltipLines({ bag = 0, slot = 1 })
        assertEqual(#lines, 2, "the secret line is skipped, not the end of the list")
        assertEqual(lines[1].text, "Soulbound")
        assertEqual(lines[1].r, 1)
        assertEqual(lines[2].text, "Requires Level 90")
        assertNil(lines[2].r, "a secret color reads nil")
        assertEqual(lines[2].g, 0.1)
        assertEqual(C.TooltipLines({ slotID = 1 })[1].text, "Head1")
        assertEqual(#C.TooltipLines("|Hitem:1|h"), 0, "a secret tooltip-data table is never indexed")
        assertEqual(#C.TooltipLines(T.secret("|Hitem:1|h")), 0)
    end)
end)

test("compat: TooltipInventoryUnit reads the primary info's getter and fails safe (O41)", function()
    local function tip(info) return { GetPrimaryTooltipInfo = function() return info end } end
    assertEqual(C.TooltipInventoryUnit(tip({ getterName = "GetInventoryItem", getterArgs = { "player", 1 } })), "player")
    assertEqual(C.TooltipInventoryUnit(tip({ getterName = "GetInventoryItem", getterArgs = { "target", 1 } })), "target")
    assertNil(C.TooltipInventoryUnit(tip({ getterName = "GetBagItem", getterArgs = { 0, 1 } })))
    assertNil(C.TooltipInventoryUnit(tip(nil)), "no primary info: not an inventory tooltip")
    -- An inventory tooltip whose unit cannot be read answers "?", which is not the player (O41).
    with(nil, function()
        -- red under: return info.getterArgs[1] from Compat.TooltipInventoryUnit without NS.Secrets.PlainString
        assertEqual(C.TooltipInventoryUnit(tip({ getterName = "GetInventoryItem", getterArgs = { T.secret("player") } })), "?")
        -- red under: answering nil for unreadable getterArgs (the gate fails open).
        assertEqual(C.TooltipInventoryUnit(tip({ getterName = "GetInventoryItem", getterArgs = T.secret({}) })), "?")
        -- red under: answering nil for an unreadable info table.
        assertEqual(C.TooltipInventoryUnit(tip(T.secret({}))), "?")
        -- red under: dropping the IsSealed(getterName) check (a secret getter reads as not-inventory).
        assertEqual(C.TooltipInventoryUnit(tip({ getterName = T.secret("GetInventoryItem"), getterArgs = { "target" } })), "?")
    end)
    -- red under: answering nil when the info call raises.
    assertEqual(C.TooltipInventoryUnit({ GetPrimaryTooltipInfo = function() error("no info") end }), "?")
    assertNil(C.TooltipInventoryUnit({}))
    assertNil(C.TooltipInventoryUnit(nil))
end)

test("compat: pet lookups compare plain names inside Compat and skip a secret one", function()
    local PETS = {
        { "BattlePet-0-1", 39, true, nil, "Mechanical Squirrel" },
        { "BattlePet-0-5", 39, true, "Pierre", "Mechanical Squirrel" },
        { "BattlePet-0-2", 1203, true, T.secret("Sir Pierre"), "Pierre" },
        { "BattlePet-0-3", 77, false, nil, "Unowned" },
        { T.secret("BattlePet-0-4"), 88, true, nil, "Hidden" },
    }
    local summoned = {}
    with({ C_PetJournal = {
        GetNumPets = function() return #PETS, #PETS end,
        GetPetInfoByIndex = function(i)
            local p = PETS[i]
            return p[1], p[2], p[3], p[4], 1, false, false, p[5]
        end,
        GetSummonedPetGUID = function() return "BattlePet-0-1" end,
        SummonPetByGUID = function(guid) summoned[#summoned + 1] = guid end } }, function()
        assertEqual(C.SummonedPetGUID(), "BattlePet-0-1")
        assertEqual(C.PetGUIDByName("Mechanical Squirrel"), "BattlePet-0-1", "case-insensitive")
        -- INV §3.10 Keep: the species name, never a custom one. A squirrel the player renamed
        -- "Pierre" sits first in the journal; the COOKING preset's Pierre is the species.
        -- red under: a PetGUIDByName that also matches the custom name (core/Compat.lua).
        assertEqual(C.PetGUIDByName("pierre"), "BattlePet-0-2", "the species, not the renamed squirrel")
        assertNil(C.PetGUIDByName("sir pierre"), "a custom name is never matched")
        assertNil(C.PetGUIDByName("unowned"), "an unowned pet is never a handle")
        assertNil(C.PetGUIDByName("hidden"), "a secret guid is never a handle")
        assertNil(C.PetGUIDByName(T.secret("pierre")))
        assertEqual(C.PetGUIDBySpecies(1203), "BattlePet-0-2")
        assertNil(C.PetGUIDBySpecies(77))
        assertTrue(C.SummonPet("BattlePet-0-2"))
        assertFalse(C.SummonPet(T.secret("BattlePet-0-2")))
        assertEqual(table.concat(summoned, ","), "BattlePet-0-2")
    end)
end)

test("compat: the hooks go through hooksecurefunc, and answer false when they cannot", function()
    local hooked, fn = {}, function() end
    local journal = { SummonPetByGUID = function() end }
    with({ hooksecurefunc = function(a, b, c) hooked[#hooked + 1] = { a, b, c } end, C_PetJournal = journal }, function()
        assertTrue(C.HookPetSummon(fn))
        assertTrue(hooked[1][1] == journal and hooked[1][2] == "SummonPetByGUID" and hooked[1][3] == fn)
        assertTrue(C.HookCompare(fn))
        assertTrue(hooked[2][1] == "GameTooltip_ShowCompareItem" and hooked[2][2] == fn)
    end)
    with({ hooksecurefunc = function() error("unknown function") end, C_PetJournal = false }, function()
        assertFalse(C.HookPetSummon(fn), "no journal: nothing to hook")
        assertFalse(C.HookCompare(fn), "a missing compare function raises in hooksecurefunc; Compat answers false")
    end)
end)

test("compat: the Equipment Manager reads walk bounded and answer plain", function()
    local SETS = { [3] = { "Tank", 134400 }, [7] = { T.secret("PvP"), 1 } }
    with({ C_EquipmentSet = {
               GetEquipmentSetIDs = function() return { 3, T.secret(9), 7 } end,
               GetEquipmentSetInfo = function(id)
                   local s = SETS[id]
                   if s then return s[1], s[2], id, true end
               end,
               GetItemLocations = function() return { [1] = 1048577, [2] = T.secret(5), [16] = -1 } end,
               GetIgnoredSlots = function() return { [4] = true, [5] = false, [19] = 1 } end,
               GetEquipmentSetID = function(name) return name == "Tank" and 3 or nil end,
               GetNumEquipmentSets = function() return 2 end },
           EquipmentManager_GetLocationData = function(loc)
               return { isPlayer = loc == 1, isBags = loc ~= 1, isBank = false, slot = 5, bag = 0, voidSlot = 9 }
           end,
           MAX_EQUIPMENT_SETS_PER_PLAYER = 20 }, function()
        assertEqual(table.concat(C.EMSetIDs(), ","), "3,7", "a secret id is skipped, not the end of the list")
        local info = C.EMSetInfo(3)
        assertEqual(table.concat({ info.name, info.icon, info.setID, tostring(info.isEquipped) }, ","),
                    "Tank,134400,3,true")
        assertNil(C.EMSetInfo(7), "a set whose name is secret cannot be matched, so it reads unreadable")
        assertNil(C.EMSetInfo(99))
        local locs = C.EMLocations(3)
        assertEqual(locs[1], 1048577)
        assertNil(locs[2], "a secret location is dropped")
        assertEqual(locs[16], -1)
        local ignored = C.EMIgnoredSlots(3)
        assertTrue(ignored[4] and ignored[19] and ignored[5] == nil)
        local d = C.FlyoutLocationData(1)
        assertTrue(d.isPlayer == true and d.isBags == false and d.slot == 5 and d.bag == 0)
        assertNil(d.voidSlot, "only the documented fields are copied")
        assertEqual(C.EMLocation(2).isBags, true)
        assertEqual(C.EMSetID("Tank"), 3)
        assertNil(C.EMSetID("Nope"))
        assertEqual(C.EMNumSets(), 2)
        assertEqual(C.EMMaxSets(), 20)
    end)
    with({ C_EquipmentSet = { GetEquipmentSetIDs = function() return T.secret({}) end } }, function()
        assertEqual(#C.EMSetIDs(), 0, "a secret id list is the zero-sets path (Q8), never indexed")
    end)
    with({ C_EquipmentSet = { GetEquipmentSetIDs = function()
        local t = {}
        for i = 1, 600 do t[i] = i end
        return t
    end } }, function()
        assertEqual(#C.EMSetIDs(), 512, "bounded at 512")
    end)
end)

test("compat: the Equipment Manager writes reach the client with their arguments", function()
    local log, api = {}, {}
    for _, name in ipairs({ "CreateEquipmentSet", "SaveEquipmentSet", "ModifyEquipmentSet", "DeleteEquipmentSet",
                            "ClearIgnoredSlotsForSave", "IgnoreSlotForSave", "UnignoreSlotForSave" }) do
        api[name] = function(...) log[#log + 1] = table.concat({ name, ... }, ":") end
    end
    with({ C_EquipmentSet = api }, function()
        assertTrue(C.EMCreateSet("Tank", 134400))
        assertTrue(C.EMSaveSet(3, 1))
        assertTrue(C.EMModifySet(3, "Tank2", 2))
        assertTrue(C.EMDeleteSet(3))
        assertTrue(C.EMClearIgnored())
        assertTrue(C.EMIgnoreSlot(4, true))
        assertTrue(C.EMIgnoreSlot(5, false))
    end)
    assertEqual(table.concat(log, ","), "CreateEquipmentSet:Tank:134400,SaveEquipmentSet:3:1,"
        .. "ModifyEquipmentSet:3:Tank2:2,DeleteEquipmentSet:3,ClearIgnoredSlotsForSave,IgnoreSlotForSave:4,"
        .. "UnignoreSlotForSave:5")
end)

test("compat: KnownTitles lists known titles by a plain case-insensitive sort, a secret name skipped", function()
    -- legacy: GetSortedTitles compared the raw names, so a secret one raised inside table.sort (INV §12);
    -- fixed: the name goes through PlainString and a secret is skipped.
    local NAMES = { "the Patient", T.secret("Hidden"), "Champion of the Frozen Wastes", "Zealot", "Unknown" }
    with({ GetNumTitles = function() return #NAMES end, IsTitleKnown = function(i) return i ~= 5 end,
           GetTitleName = function(i) return NAMES[i] end }, function()
        -- red under: drop NS.Secrets.PlainString on GetTitleName in Compat.KnownTitles (:lower() raises)
        local list = C.KnownTitles()
        assertEqual(#list, 3)
        assertEqual(list[1].id, 3)
        assertEqual(list[2].name, "the Patient", "case-insensitive: a raw compare puts Zealot first")
        assertEqual(list[3].name, "Zealot")
    end)
end)

test("compat: BankBagIDs reads the character bank tabs, else the bank and its bags", function()
    with({ Enum = { BagIndex = { Bank = -1, CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, AccountBankTab_1 = 12 } } },
        function()
            assertEqual(table.concat(C.BankBagIDs(), ","), "6,7", "the warband tabs are not scanned (O19)")
        end)
    with({ Enum = { BagIndex = { Bank = -1, BankBag_1 = 6, BankBag_2 = 7, BankBag_3 = 8 } } }, function()
        assertEqual(table.concat(C.BankBagIDs(), ","), "-1,6,7,8")
    end)
    with({ Enum = { PlayerInteractionType = { Banker = 8, AccountBanker = 68 } } }, function()
        assertTrue(C.IsBankerInteraction(8))
        assertFalse(C.IsBankerInteraction(68), "the warband banker is not the bank (O19)")
        assertFalse(C.IsBankerInteraction(T.secret(8)))
    end)
end)

test("compat: pickups, uses and the cursor route by location and report the call", function()
    local log = {}
    local function rec(name) return function(...) log[#log + 1] = table.concat({ name, ... }, ":") end end
    with({ C_Container = {
               PickupContainerItem = rec("PickupContainerItem"), UseContainerItem = rec("UseContainerItem"),
               ShowContainerSellCursor = rec("ShowContainerSellCursor"),
               GetContainerNumSlots = function(bag) return bag == 0 and 16 or T.secret(4) end,
               GetContainerNumFreeSlots = function() return 3, 8 end,
               ContainerIDToInventoryID = function(bag)
                   if bag < 1 then error("invalid bag") end
                   return 30 + bag
               end },
           PickupInventoryItem = rec("PickupInventoryItem"), EquipCursorItem = rec("EquipCursorItem"),
           ClearCursor = rec("ClearCursor"), SetCurrentTitle = rec("SetCurrentTitle") }, function()
        assertTrue(C.PickupItemLocation({ bag = 2, slot = 5 }))
        assertTrue(C.PickupItemLocation({ slotID = 16 }))
        assertFalse(C.PickupItemLocation({}), "no shape: no client call")
        assertTrue(C.UseContainerItem(1, 2))
        assertTrue(C.ShowContainerSellCursor(1, 3))
        assertTrue(C.EquipCursorItem(16))
        assertTrue(C.ClearCursor())
        assertTrue(C.SetCurrentTitle(42))
        assertEqual(C.ContainerNumSlots(0), 16)
        assertEqual(C.ContainerNumSlots(1), 0, "a secret count reads 0")
        local free, family = C.ContainerNumFreeSlots(1)
        assertEqual(free, 3)
        assertEqual(family, 8)
        assertEqual(C.ContainerIDToInventoryID(1), 31)
        assertNil(C.ContainerIDToInventoryID(0), "a raising client call reads nil")
    end)
    assertEqual(table.concat(log, ","), "PickupContainerItem:2:5,PickupInventoryItem:16,UseContainerItem:1:2,"
        .. "ShowContainerSellCursor:1:3,EquipCursorItem:16,ClearCursor,SetCurrentTitle:42")
end)

test("compat: macro icons, Pawn scales and values, dual wield and BitAnd", function()
    with({ GetMacroItemIcons = function(t) t[1], t[2] = 135349, "INV_Misc_QuestionMark" end,
           GetMacroIcons = function(t) t[1] = 136243 end,
           PawnGetAllScales = function() return { "Zeta", "Alpha", T.secret("Hidden"), "Hidden scale" } end,
           PawnIsScaleVisible = function(name) return name ~= "Hidden scale" end,
           PawnGetItemData = function(link)
               if link == "boom" then error("Pawn raised") end
               return { Values = { { "Alpha", 12.5 }, { "Zeta", T.secret(3) } } }
           end,
           CanDualWield = function() return 1 end }, function()
        assertEqual(#C.MacroIcons("item"), 2)
        assertEqual(C.MacroIcons("ability")[1], 136243)
        assertEqual(#C.MacroIcons("other"), 0)
        assertEqual(table.concat(C.PawnVisibleScales(), ","), "Alpha,Zeta", "visible, plain and sorted")
        assertEqual(C.PawnItemValue("link", "Alpha"), 12.5)
        assertNil(C.PawnItemValue("link", "Zeta"), "a secret score reads nil; the caller scores it 0")
        assertNil(C.PawnItemValue("link", "Beta"))
        assertNil(C.PawnItemValue("boom", "Alpha"), "a raising Pawn is contained (H16)")
        assertEqual(C.CanDualWield(), true)
    end)
    assertEqual(C.BitAnd(12, 6), 4)
    assertEqual(C.BitAnd(0, 255), 0)
    assertEqual(C.BitAnd(0x400, 0x7FF), 0x400)
    assertEqual(C.BitAnd(0x80000000, 0xFFFFFFFF), 0x80000000)
    assertEqual(C.BitAnd(nil, 1), 0, "a non-number is no bits")
end)

-- ── the engine, on the whole login (P4.27) ────────────────────────────────────────────────────

--- The whole login on the secret_slots scenario (a secret helm worn and carried), zoned in, with the
--- client's issecretvalue installed; `fn(ns, M)` runs inside, the simulator restored however it leaves.
local function engine(fn)
    local restore = T.installSecretValue()
    local ok, err = pcall(function()
        local inst = T.load({ mutate = function(M) M.__gear:load("secret_slots") end })
        local ns, M = inst.NS, inst.mocks
        M.__fire("PLAYER_ENTERING_WORLD")
        for _ = 1, 4 do if M.__fireTimers() == 0 then break end end
        fn(ns, M)
    end)
    restore()
    if not ok then error(err, 0) end
end

local DB = T.fixtures.items.db

test("secrets engine: a secret worn or carried link is an empty slot to the live scan", function()
    engine(function(ns)
        local cache = ns.Inventory.Cache()
        -- red under: Compat.InventoryItemLink / ContainerItemLink handing the raw link through.
        assertNil(cache.byID[DB.secret_helm.id], "the secret helm was cached")
        assertTrue(cache.byID[DB.chest_plate.id] ~= nil, "the plain chest is cached; the scan ran")
        assertFalse((ns.Inventory.Sync()), "a secret slot reads the same empty slot every time")
    end)
end)

test("secrets engine: a secret player level lets an item through the live stats", function()
    engine(function(ns, M)
        M.UnitLevel = function() return T.secret(80) end
        -- red under: an unreadable level read as 0 (an item with a minimum level would score 0).
        assertTrue(ns.Stats.Get("STA"):Score(ns.ItemInfo.FromLink(DB.head_plate.link)) > 0)
    end)
end)

test("secrets engine: tooltip, compare, quick slots and /of iteminfo refuse a secret link quietly", function()
    -- red under: a Secrets.PlainString in core/Secrets.lua without its IsSealed test (the secret link
    -- reaches the used-by, compare, quick-slot and iteminfo string work and raises). Each tooltip half
    -- has a plain-link control first, so its silence on the secret link is the guard, not an empty
    -- scene. The type() the client answers for a secret (its underlying type) is modeled from here
    -- on: the kit answers "table", which every type check would refuse with no guard at all.
    engine(function(ns, M)
        local tip = M.GameTooltip
        M.type = function(v)
            if T.isSecret(v) then return type(T.reveal(v)) end
            return type(v)
        end
        local function snap(key) return ns.ItemInfo.Snapshot(ns.ItemInfo.FromLink(DB[key].link)) end
        -- The helm the compare half offers, and the carried ring (bag 0, 2) the used-by half finds.
        ns.Outfits.Create("Veil", { HeadSlot = snap("secret_helm"), Finger0Slot = snap("ring_plain_a") })
        local function usedBy()
            assertTrue(pcall(M.__world.tooltipPostCall, M.__world, M.Enum.TooltipDataType.Item, tip, nil),
                "the used-by post-call raised")
            for i = 1, tip:NumLines() do
                local text = tip["TextLeft" .. i]:GetText()
                if type(text) == "string" and text:find("Equipment Sets: ", 1, true) == 1 then return true end
            end
            return false
        end
        local function compares(link)
            tip:SetHyperlink(link)
            tip:Show()
            assertTrue(pcall(M.GameTooltip_ShowCompareItem, tip), "the compare hook raised")
            local shown = 0
            for i = 1, 10 do
                local c = M["OutfitterRebornCompareTooltip" .. i]
                if c and c:IsShown() then shown = shown + 1 end
            end
            tip:Hide()
            return shown
        end
        tip:SetHyperlink(DB.ring_plain_a.link)                -- the carried ring, read plain
        assertTrue(usedBy(), "no used-by line for the plain link; the secret half below proves nothing")
        tip:SetHyperlink(T.secret(DB.ring_plain_a.link))      -- the same ring, read secret
        assertFalse(usedBy(), "a used-by line for a secret link")
        tip:SetBagItem(0, 1)                                  -- the secret helm
        assertFalse(usedBy(), "a used-by line for a secret bag link")
        M.__world:setCompare(true, true)
        assertTrue(compares(DB.head_plate.link) > 0,
            "no compare tooltip for the plain link; the secret half below proves nothing")
        assertEqual(compares(T.secret(DB.head_plate.link)), 0, "a compare tooltip for a secret link")
        local PLAYER, BAGS = 0x00100000, 0x00200000
        assertNil((ns.QuickSlots.Sort.LocationItemLink(PLAYER + BAGS + 1)), "a secret bag link")
        assertNil((ns.QuickSlots.Sort.LocationItemLink(PLAYER + 1)), "a secret worn link")
        local lines = ns.ItemInfo.LinkInfoLines(T.secret(DB.head_plate.link))
        assertEqual(lines[2], ns.L["Not a readable item link."])
    end)
end)

test("secrets engine: the Equip count is balanced after a raise inside a Batch", function()
    engine(function(ns, M)
        local errors = 0
        M.geterrorhandler = function() return function() errors = errors + 1 end end
        local E = ns.Equip
        -- red under: an E.Batch that lowers the depth only on success (the count strands at 1).
        local ok = pcall(E.Batch, function() error("a raise mid-swap") end)
        assertTrue(not ok or errors == 1, "the raise was swallowed unseen")
        assertEqual(E.__state.depth, 0, "the count stranded after a raise")
        E.Request()
        assertTrue(E.Pending(), "a request after the raise is not wanted")
    end)
end)

-- ── the seam scan ─────────────────────────────────────────────────────────────────────────────

-- The client APIs whose answers may be secret: a module that names one has read a value it may not
-- inspect. Each is matched as a bare global (not `X.UnitLevel`, not `X:UnitLevel`), as a prefix, so
-- UnitHealthMax and UnitPowerType count too.
local SECURABLE = { "UnitHealth", "UnitPower", "UnitStat", "UnitLevel", "C_UnitAuras", "UnitAura",
                    "UnitBuff", "UnitDebuff", "AuraUtil", "GetPlayerAuraBySpellID" }

-- The files allowed to name them: the compat family, the secrets seam and the state producer.
local function allowed(rel)
    return rel:find("^core/Compat[%w]*%.lua$") ~= nil or rel == "core/Secrets.lua"
        or rel == "modules/States.lua"
end

-- Comments and string literals stripped, so a mention in prose or a message is not a call.
local function stripped(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    text = text:gsub("%[(=*)%[.-%]%1%]", '""')
    text = text:gsub("%-%-[^\n]*", "")
    text = text:gsub('"[^"\n]*"', '""'):gsub("'[^'\n]*'", "''")
    return text
end

-- The securable names `text` reads as globals.
local function securableReads(text)
    local code = "\n" .. stripped(text)
    local hits = {}
    for _, name in ipairs(SECURABLE) do
        if code:find("[^%w_%.:]" .. name) then hits[#hits + 1] = name end
    end
    return hits
end

-- Every authored Lua file: the TOC's, plus any on disk in the addon folders the TOC does not list yet.
local function authoredFiles()
    local seen, out = {}, {}
    local function add(rel)
        rel = rel:gsub("\\", "/"):gsub("^%./", "")
        if not seen[rel] then
            seen[rel] = true
            out[#out + 1] = rel
        end
    end
    for _, rel in ipairs(T.loadedAddonFiles) do add(rel) end
    local p = io.popen('cd "' .. T.root .. '" && find core defaults locales modules settings -name "*.lua" 2>/dev/null')
    if p then
        for line in p:lines() do add(line) end
        p:close()
    end
    return out
end

test("secrets seam: the scanner catches a securable read and nothing else (mutation self-test)", function()
    assertEqual(#securableReads("local h = UnitHealth('player')"), 1)
    assertEqual(#securableReads("local m = UnitPowerMax('player', 0)"), 1, "the prefix catches the variants")
    assertEqual(#securableReads("if C_UnitAuras.GetAuraDataByIndex then end"), 1)
    assertEqual(#securableReads("return UnitLevel(unit)"), 1)
    assertEqual(#securableReads("local l = NS.Compat.UnitLevel()"), 0, "a Compat member is not the global")
    assertEqual(#securableReads("local l = Compat:UnitLevel()"), 0)
    assertEqual(#securableReads("-- UnitHealth is read in Compat only"), 0, "a comment is not a read")
    assertEqual(#securableReads('print("UnitStat")'), 0, "a string is not a read")
    assertEqual(#securableReads("local MyUnitLevel = 1"), 0, "a longer identifier is not the global")
    assertTrue(allowed("core/Compat.lua"))
    assertTrue(allowed("core/Secrets.lua"))
    assertTrue(allowed("modules/States.lua"))
    assertFalse(allowed("modules/Equip.lua"))
    assertFalse(allowed("modules/States_Zone.lua"))
end)

test("secrets seam: no securable client API is named outside the compat family, Secrets and States", function()
    local files = authoredFiles()
    assertTrue(#files > 0, "no authored files found; nothing below can fail")
    local scanned = 0
    for _, rel in ipairs(files) do
        if not allowed(rel) then
            local f = assert(io.open(T.root .. "/" .. rel, "r"))
            local text = f:read("*a")
            f:close()
            scanned = scanned + 1
            local hits = securableReads(text)
            assertEqual(#hits, 0, rel .. " names " .. table.concat(hits, ", "))
        end
    end
    assertTrue(scanned > 0, "every file was allowed; the scan scanned nothing")
end)
