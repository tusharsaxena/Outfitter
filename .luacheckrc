std = "lua51"
max_line_length = false
codes = true

-- libs/ and tests/_kit/ are byte copies of code linted in its own repo (LibKa0s); linting the copy
-- would report every finding twice and let the copy drift green (lint). The frozen docs/ bundles must
-- never be "fixed" by a lint pass.
exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/" }

-- No top-level `ignore`: a blanket reaches every file, including the ones with no business producing
-- the code it silences (lint). A receiver a calling convention forces gets a per-file stanza below.

read_globals = {
    "_G", "LibStub", "CreateFrame", "GetTime", "UIParent", "STANDARD_TEXT_FONT",
    "DEFAULT_CHAT_FRAME", "UISpecialFrames",
    -- the perf bracket's clock (performance-§2)
    "debugprofilestop",
    "C_Timer", "C_AddOns", "Enum", "GetLocale",
    -- combat state: InCombatLockdown() gates secure writes; UnitAffectingCombat() drives display
    "InCombatLockdown", "UnitAffectingCombat",
    "UnitGUID", "UnitName", "UnitClass",
    -- settings panel plumbing
    "Settings", "SettingsPanel", "StaticPopup_Show",
}

globals = {
    "OutfitterRebornDB",      -- the SavedVariables write target (the AceDB tree)
    "OutfitterRebornPerfDB",  -- the LibKa0s-Perf capture ring, outside the AceDB tree (performance-§5)
    "StaticPopupDialogs",     -- the addon registers its named popups into this table
    "BINDING_HEADER_OUTFITTERREBORN",   -- the key-binding category (launcher-§6); BINDING_NAME_* go via rawset
    "OutfitterReborn",        -- the public API table, _G.OutfitterReborn.API.v1 (H3)
}

-- The test tree is linted; these are the globals it WRITES. Scoped here so no shipped file can reach
-- for the harness.
files["tests/"] = {
    globals = { "_G.OUTFITTERREBORN_TEST", "_G.OutfitterRebornDB", "_G.OutfitterRebornPerfDB" },
}

-- `NS:InitDB` / `NS:RunMigrations` are colon-called from OnInitialize and read NS.db, not the receiver.
files["core/Database.lua"] = { ignore = { "212/self" } }

-- AceEvent invokes a handler registered by method name as `self[name](self, event, ...)`.
files["core/OutfitterReborn.lua"] = { ignore = { "212/self" } }

-- The compat family (compat.md :7): the version-variant client calls and the client's secret
-- detectors, readable from this one file only, so "the client is read only through NS.Compat" is a
-- lint fact (design §1.5). core/Secrets.lua names no client global; it binds this file's guards.
-- C_SpecializationInfo and the bare IsAddOnLoaded are the upper and lower rungs of two ladders.
files["core/Compat.lua"] = {
    read_globals = {
        "issecretvalue", "canaccessvalue", "issecrettable", "canaccesstable",
        "C_SpecializationInfo", "GetSpecialization", "GetSpecializationInfo", "GetNumSpecializations",
        "UnitFactionGroup", "UnitLevel", "UnitIsDeadOrGhost", "GetCVar", "SetCVar", "C_PlayerInfo",
        "IsAddOnLoaded",
        "UnitCastingInfo", "UnitChannelInfo",   -- Compat.PlayerCasting (P4.4 handback, design §5.2)
        -- P4.2's accessors (design §5.13): items, containers, the Equipment Manager, pets, tooltip data,
        -- titles and macro icons. Every equipment call lives here and nowhere else.
        "C_Container", "C_Item", "C_ItemUpgrade", "C_EquipmentSet", "C_PetJournal", "C_TooltipInfo",
        "C_AzeriteEmpoweredItem", "GetInventoryItemLink", "GetInventoryItemID", "GetInventorySlotInfo",
        "GetInventoryItemCooldown", "PickupInventoryItem", "EquipCursorItem", "ClearCursor", "CursorHasItem",
        "GetCursorInfo", "SetCurrentTitle", "GetMacroIcons", "GetMacroItemIcons",
        "EquipmentManager_GetLocationData", "PawnGetItemData", "GetNumTitles", "GetTitleName", "IsTitleKnown",
        "ItemLocation", "hooksecurefunc", "MAX_EQUIPMENT_SETS_PER_PLAYER", "PawnGetAllScales", "PawnIsScaleVisible",
        "CanDualWield",
        "NUM_TOTAL_EQUIPPED_BAG_SLOTS",   -- Compat.LastEquippedBagID (P4.5 handback)
        "IsFlying",                       -- Compat.IsFlying (P4.13 handback)
    },
}

-- The skin seam falls back to the client's item-quality colors where the skin sets no q.* token.
files["core/SkinSetup.lua"] = { read_globals = { "ITEM_QUALITY_COLORS" } }

-- The degraded context menu hands its `fill` to the client's own menu (core/WidgetsSetup.lua).
files["core/WidgetsSetup.lua"] = { read_globals = { "MenuUtil" } }

-- A queued protected write that raises goes to the client's error handler, and the next one runs.
files["core/SecureQueue.lua"] = { read_globals = { "geterrorhandler" } }

-- The equipment bracket surfaces a failed update through the client error handler, with its stack.
files["modules/Equip.lua"] = { read_globals = { "geterrorhandler", "debugstack" } }

-- ── the P4 modules' client reads (design §1.5), declared whole in P4.0 ────────────────────────────
-- Each stanza names only what its files may touch. Every engine module not listed here names NO
-- client global: it reads the client through NS.Compat (design §5), and luacheck makes that a fact.
-- This file is a spine file (design §12): a task that needs another global hands it back.

-- The state producers: auras (behind the restriction check), forms, movement, the unit reads the
-- Secrets seam guards, and the GameTooltip OnShow/OnHide hooks.
files["modules/States.lua"] = {
    read_globals = {
        "C_UnitAuras", "C_RestrictedActions", "GetShapeshiftFormInfo", "GetNumShapeshiftForms", "IsMounted",
        "IsSwimming", "UnitOnTaxi", "UnitPower", "UnitPowerMax", "UnitHealth", "UnitHealthMax", "GameTooltip",
        "UnitPowerType",   -- PlayerIsFull (P4.14 handback)
    },
}

-- The zone producer: map IDs first, the zone texts only for /of zone's report (H9).
files["modules/States_Zone.lua"] = {
    read_globals = {
        "C_Map", "GetInstanceInfo", "IsInInstance", "GetZoneText", "GetMinimapZoneText", "GetRealZoneText",
    },
}

-- The trigger files: the reads their conditions make and the two effects that act on the client.
local TRIGGER_READS = {
    "IsFalling", "IsResting", "UnitIsPVP", "UnitGUID", "UnitIsPlayer", "UnitName", "UnitInVehicle",
    "C_QuestLog", "C_TradeSkillUI", "C_Minimap", "SpellIsTargeting", "HasFullControl", "DoEmote",
    "ChangeActionBarPage", "IsInInstance", "C_Map", "GameTooltip", "C_Spell", "C_Item", "C_PetJournal",
    "C_UnitAuras", "GetCursorInfo", "GetMinimapZoneText", "GetNormalizedRealmName", "GetActionBarPage",
    "GetInstanceInfo",
}
for _, f in ipairs({ "modules/Triggers_Params.lua", "modules/Triggers_Families.lua",
                     "modules/Triggers_CondGeneral.lua", "modules/Triggers_CondTrade.lua",
                     "modules/Triggers_CondQuest.lua", "modules/Triggers_Effects.lua",
                     "modules/Triggers_Binder.lua" }) do
    files[f] = { read_globals = TRIGGER_READS }
end
-- The trigger catalog: the zone text a captured zone trigger reads.
files["modules/Triggers.lua"] = { read_globals = { "GetRealZoneText" } }

-- The tooltip lines and the compare tooltips: the post-call processor, the shopping tooltips, and the
-- EQUIPMENT_SETS line the outfit line replaces.
for _, f in ipairs({ "modules/Tooltips.lua", "modules/Tooltips_Compare.lua", "modules/OutfitTooltip.lua" }) do
    files[f] = {
        read_globals = {
            "TooltipDataProcessor", "TooltipUtil", "GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
            "EQUIPMENT_SETS", "hooksecurefunc", "IsModifiedClick", "GetScreenWidth",
        },
    }
end

-- The dock, the window and the slot checkboxes sit on the character sheet and stack with it.
for _, f in ipairs({ "modules/Dock.lua", "modules/Window.lua", "modules/Window_ListModel.lua",
                     "modules/Window_Rows.lua", "modules/SlotEnables.lua" }) do
    files[f] = {
        read_globals = {
            "CharacterFrame", "PaperDollFrame", "CharacterFrameCloseButton", "ToggleCharacter", "UISpecialFrames",
            "GameTooltip", "SpellCanTargetItem", "SpellCanTargetItemID", "MerchantFrame", "CursorHasItem",
        },
    }
end

-- The flyout hooks.
for _, f in ipairs({ "modules/QuickSlots.lua", "modules/QuickSlots_Sort.lua" }) do
    files[f] = {
        read_globals = {
            "PaperDollItemsFrame", "EquipmentFlyout_Hide", "EquipmentFlyoutPopoutButton_OnClick", "hooksecurefunc",
            -- P4.18 handback: the cursor, the flyout frame and its location bits.
            "CursorHasItem", "EquipmentFlyoutFrame", "EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION",
            "EQUIPMENTFLYOUT_PLACEINBAGS_LOCATION", "ITEM_INVENTORY_LOCATION_PLAYER", "ITEM_INVENTORY_LOCATION_BAGS",
            "ITEM_INVENTORY_LOCATION_BANK",
        },
    }
end

-- The bar and the icon chooser take a dropped spell, item or macro as an icon.
for _, f in ipairs({ "modules/Bar.lua", "modules/Bar_Buttons.lua", "modules/IconChooser.lua" }) do
    files[f] = {
        read_globals = {
            "GetCursorInfo", "C_Spell", "C_Item", "GetMacroInfo", "IsAltKeyDown",
            "UIFrameFadeOut", "UIFrameFadeRemoveFrame", "GameTooltip",
        },
    }
end

-- The published slash surface is colon-called by the host and the suites and forwards to the
-- dispatcher upvalue.
files["settings/Slash.lua"] = {
    ignore = { "212/self" },
    -- the client's macro-option parser decides a conditional message or argument (H25)
    read_globals = { "SecureCmdOptionParse" },
}

-- The mocks mirror the client's and the libraries' colon-called APIs (`db:SetProfile`, `frame:Show`).
files["tests/wow_mock.lua"] = { ignore = { "212/self", "432/self" } }
files["tests/mock_gear.lua"] = { ignore = { "212/self", "432/self" } }
files["tests/mock_world.lua"] = { ignore = { "212/self", "432/self" } }

-- The legacy capture tool (§9.4) drives the RETIRED harness inside a read-only worktree of the old
-- addon: it steers that harness's mock by replacing client functions on its global table (`G` is
-- `_G` there) and calls the old addon's slash handler. Never loaded by the client, never shipped.
files["tools/legacy_capture.lua"] = {
    globals = { "_G.GetNumSpecializations", "_G.GetSpecializationInfo", "_G.UnitClass", "_G.C_Item" },
    read_globals = { "SlashCmdList" },
}
