-- tests/run.lua — this addon's load list, lifecycle kick and suite list, on the vendored kit
-- (testing-§1). Run from the repo root: `lua tests/run.lua` (`--list` writes docs/test-cases.md).

local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/run%.lua$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path

local Kit     = dofile(root .. "/tests/_kit/framework.lua")
local Loader  = dofile(root .. "/tests/_kit/loader.lua")
local mockmod = assert(loadfile(root .. "/tests/wow_mock.lua"))(root)

Loader.addonName = "OutfitterReborn"

-- The vendored library's files, read out of LibKa0s.xml in its own order rather than remembered:
-- omit one and its module refuses to register, the host takes its stub, and the suite measures the
-- stub -- green, and testing nothing (testing-§9). The floor below fails loudly if the .xml ever
-- stops naming a file of one of the sixteen majors this addon leases (§1.3; Glow, Toast, Charts and
-- Sim load with the rest of the .xml and are not leased).
local LIB_FILES = Loader.xmlFiles(root .. "/libs/LibKa0s/LibKa0s.xml")
do
    local EXPECTED = {
        "Core.lua", "Env.lua", "Compat.lua", "Lifecycle.lua", "Bus.lua", "Schema.lua", "Pool.lua",
        "Item.lua", "Media.lua", "MediaIcons.lua",
        "Skin.lua", "SkinOwnerTokens.lua", "SkinDefs.lua", "SkinDefsOthers.lua", "SkinPaint.lua",
        "SkinPaintControls.lua", "SkinPaintExtras.lua", "SkinEUI.lua", "SkinAce.lua",
        "Widgets.lua", "WidgetsDragHandle.lua", "WidgetsCopyWindow.lua",
        "DebugLog.lua", "DebugLogDiagnostics.lua", "DebugLogGates.lua", "DebugLogWindow.lua",
        "Slash.lua", "SlashParse.lua", "Launcher.lua",
        "Options.lua", "OptionsRegistry.lua", "OptionsWidgets.lua", "OptionsFlow.lua", "OptionsTabs.lua",
        "OptionsTabbed.lua", "OptionsCombat.lua", "OptionsCompose.lua", "OptionsScroll.lua",
        "OptionsKeybinds.lua", "OptionsAppearance.lua", "OptionsSkinPicker.lua", "OptionsSkinPickerRows.lua",
        "OptionsSwitch.lua", "OptionsMedia.lua",
        "Perf.lua", "PerfSampler.lua", "PerfCommands.lua", "PerfPanel.lua",
    }
    local present = {}
    for _, path in ipairs(LIB_FILES) do present[path:match("([^/]+)$")] = true end
    local missing = {}
    for _, name in ipairs(EXPECTED) do
        if not present[name] then missing[#missing + 1] = name end
    end
    assert(#missing == 0, "libs/LibKa0s/LibKa0s.xml is missing " .. table.concat(missing, ", "))
end

-- The addon's own files come from the TOC, so this runner cannot drift from what the client loads.
local ADDON_FILES = Loader.tocFiles(root .. "/OutfitterReborn.toc")

local function rooted(list)
    local out = {}
    for i, rel in ipairs(list) do out[i] = root .. "/" .. rel end
    return out
end

-- THE SKIN LIBRARY'S LOGIN RETRY, SETTLED AS THE CLIENT SETTLES IT. The first RegisterOwner
-- (core/SkinSetup.lua) makes LibKa0s-Skin-1.0's EllesmereUI retry frame, registered for ADDON_LOADED
-- and PLAYER_LOGIN; the client fires PLAYER_LOGIN once, beside OnEnable, and the frame unregisters
-- both. Delivering it there puts the frame where every real session has it, so the stand-down suites
-- do not count the library's two events as this addon's (DPS Race's runner does the same).
local function settleSkinLogin(mocks)
    local skinLib = mocks.LibStub("LibKa0s-Skin-1.0", true)
    local retry = skinLib and skinLib.__euiEventFrame
    if retry and retry.__fire then retry:__fire("OnEvent", "PLAYER_LOGIN") end
end

--- One isolated instance: a fresh mock, a fresh NS, the client's lifecycle.
---   opts.libFiles  the LibKa0s files to load ({} = the library-absent load)
---   opts.mutate    function(mocks) run before anything loads
---   opts.init      false = load the files only (no OnInitialize)
---   opts.enable    false = initialize but do not enable
local function loadInstance(opts)
    opts = opts or {}
    local mocks = mockmod.build()
    if opts.mutate then opts.mutate(mocks) end
    -- `_G` inside a loaded chunk is the mocked environment, as in the client it is the one global table.
    mocks._G = Loader.makeEnv(mocks)
    _G.OutfitterRebornDB, _G.OutfitterRebornPerfDB = nil, nil
    local NS = {}
    Loader.loadAll(opts.libFiles or LIB_FILES, NS, mocks)
    Loader.loadAll(rooted(ADDON_FILES), NS, mocks)
    if opts.init ~= false then
        local AceAddon = mocks.LibStub("AceAddon-3.0")
        AceAddon:InitializeAddon(NS)                 -- OnInitialize: DB, migrations
        if opts.enable ~= false then
            settleSkinLogin(mocks)                   -- PLAYER_LOGIN, to the skin's retry frame
            AceAddon:EnableAddon(NS)                 -- OnEnable
            if mocks.__fireTimers then mocks.__fireTimers() end
        end
    end
    return { NS = NS, mocks = mocks }
end

local shared = loadInstance()

-- The legacy behavior fixtures (tests/fixtures/legacy/, generated in P3 C2 from 7ea3dc3), each
-- loaded on first read and kept: `T.legacy.zones` is fixtures/legacy/zones.lua's table.
local Legacy = setmetatable({}, {
    __index = function(t, name)
        local v = dofile(root .. "/tests/fixtures/legacy/" .. tostring(name) .. ".lua")
        rawset(t, name, v)
        return v
    end,
})

-- Every kit suite is declared against the kit's directory, and every one is live (§11 Gates):
-- `test_prose` joined with the doc set's US-English rewrite (P3 C16), which deleted the temporary
-- `## Documented deviations` row that had declined it.
local SUITES = {
    "test_skeleton",
    "test_toc",
    "test_loadorder",
    "test_database",
    "test_packaging",
    "test_vendor_sync",
    "test_secrets",
    "test_bus",
    "test_skinsetup",
    "test_surface_parity",
    "test_perf_harness",
    "test_schema",
    "test_settings",
    "test_slash",
    "test_launcher",
    "test_keybinds",
    "test_disabled",
    "test_locale",
    "test_glyphs",
    "test_file_budget",
    "test_removed_apis",
    -- P4 suites (design §9.3), one line each, pending until the task in its `pending` writes the file.
    -- That task drops the field in the same commit (design §12): the kit errors on a `pending` entry
    -- whose file exists, and the line is the only one in this file the task may touch. The blank line
    -- between two tasks' lines is the unchanged line that lets parallel flips merge cleanly.
    { name = "test_mock_gear" },

    { name = "test_slots" },
    { name = "test_zones" },

    { name = "test_itemlink" },

    { name = "test_item_match" },
    { name = "test_inventory" },

    { name = "test_outfits" },
    { name = "test_reset" },

    { name = "test_equip_plan" },

    { name = "test_item_stats" },

    { name = "test_companion" },

    { name = "test_states" },
    { name = "test_secrets_states" },

    { name = "test_quickslots" },

    { name = "test_equip_bracket" },

    { name = "test_tooltips" },

    { name = "test_stack" },

    { name = "test_em_sync" },
    { name = "test_bank" },

    { name = "test_optimize" },

    { name = "test_triggers" },
    { name = "test_trigger_binder" },
    { name = "test_no_loadstring" },

    { name = "test_api" },

    { name = "test_triggers_general" },

    { name = "test_triggers_trade" },

    { name = "test_triggers_quest" },

    { name = "test_triggers_class" },
    { name = "test_triggers_pvp" },

    { name = "test_sheet" },
    { name = "test_dock" },
    { name = "test_list_model" },
    { name = "test_rows_secure" },
    { name = "test_slot_enables" },

    { name = "test_bar" },
    { name = "test_outfit_icons" },

    { name = "test_triggers_parity" },

    { name = "test_preview" },

    { name = "test_outfit_menu" },
    { name = "test_dialogs" },
    { name = "test_trigger_dialog" },

    { name = "test_diagnostics" },

    { name = "test_credits" },

    { name = "test_skin" },

    { name = "test_skin_values", dir = "tests/_kit/" },
    { name = "test_skin_switch", dir = "tests/_kit/" },
    { name = "test_eol", dir = "tests/_kit/" },
    { name = "test_layout_cap", dir = "tests/_kit/" },
    { name = "test_diagnostics_contract", dir = "tests/_kit/" },
    { name = "test_lizard_sighted", dir = "tests/_kit/" },
    { name = "test_prose", dir = "tests/_kit/" },
}

_G.OUTFITTERREBORN_TEST = Kit.expose{
    root             = root,
    NS               = shared.NS,
    mocks            = shared.mocks,
    load             = loadInstance,
    libFiles         = LIB_FILES,
    loadedAddonFiles = ADDON_FILES,
    Loader           = Loader,
    legacy           = Legacy,
    secret           = Kit.secret,
    isSecret         = Kit.isSecret,
    reveal           = Kit.reveal,
    installSecretValue = Kit.installSecretValue,
    -- The domain mocks (P4.1): T.fake(NS, "Stack", {...}) for a module that has not landed (design
    -- §12, the fake rule), the item fixtures, and the gear and world scenario halves.
    fake             = mockmod.fake,
    fixtures         = mockmod.fixtures,
    gear             = mockmod.gear,
    world            = mockmod.world,
}

-- The fake rule's "for the length of the case, restored after" (design §12): the kit has no per-case
-- teardown, so every case registered through T.test ends by restoring the fakes it installed
-- (T.fake without a body), pass or fail, before the next case runs.
do
    local T, kitTest = _G.OUTFITTERREBORN_TEST, Kit.test
    T.test = function(name, fn, skipReason)
        if type(fn) ~= "function" then return kitTest(name, fn, skipReason) end
        return kitTest(name, function(...)
            local ok, err = pcall(fn, ...)
            mockmod.restoreFakes()
            if not ok then error(err, 0) end
        end, skipReason)
    end
end

-- The typed-value gate (skinning-§1): what no kit category takes, each with its cause. None yet: the
-- only colors typed so far are core/SkinSetup.lua's, which the kit reads as the seam.
Kit.skinValues = { root = root, rows = {} }

-- The skin-switch test's painted surfaces (skinning-§1): the design §9.5 builders (P4.30).
Kit.skinSwitch = dofile(root .. "/tests/skin_surfaces.lua")(_G.OUTFITTERREBORN_TEST)

-- The diagnostics contract runs against THIS addon's dispatcher (debug-logging-§14), on an instance
-- of its own so a case that stands the addon down never reaches the shared one.
local contractInst
local function contract()
    contractInst = contractInst or loadInstance()
    return contractInst
end
Kit.diagnostics = {
    brand       = "Ka0s Outfitter Reborn",
    dispatch    = function(line) contract().NS.Slash:OnSlash(line) end,
    console     = function() return contract().NS.DebugLog end,
    setDebug    = function(on) contract().NS.State.debug = on and true or false end,
    setDisabled = function(off) contract().NS.SetByPath("enabled", not off) end,
}

-- The 1500-line cap gate's census lives in the hub (layout-§1); nothing here is generated data.
Kit.layoutCap = { hub = "docs/ARCHITECTURE.md", exempt = {} }

Kit.run{ dir = root .. "/tests/", suites = SUITES }
