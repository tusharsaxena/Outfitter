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
    },
}

-- The published slash surface is colon-called by the host and the suites and forwards to the
-- dispatcher upvalue.
files["settings/Slash.lua"] = { ignore = { "212/self" } }

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
