local addonName, NS = ...
-- settings/General.lua — the General page (its first tab is `Master controls`, options-ui-§15, its last
-- `Keybindings`, options-ui-§20) and the landing page's spec, NS.LANDING (options-ui-§5).
--
-- P3 scaffold: the Behavior and Tooltips tabs arrive with their rows in P4.23 (design §4.2), between
-- Master controls and Skin. The Skin rows land here, with the write seam they need (core/SkinSetup.lua
-- writes every half of a choice through NS.SetByPath). Several Master reactions reach modules that land in P4 (the outfit bar, test
-- mode, the launcher); each is resolved at CALL time and stands aside while its module is absent.

local L = NS.L
local H = NS.Helpers
local D = NS.defaults.profile
local PAGE = "general"

-- ── The landing page ────────────────────────────────────────────────────────────────────────────
-- Logo, tagline, the command list and the credits line; the library draws them pool-safely
-- (options-ui-§19). The credits line replaces the old About panel; the full table is the README's.
NS.CREDITS_LINE = L["Originally created by John Stephen (mundocani). Maintained by aDd1kTeD2Ka0s, with thanks to Nulian and every earlier maintainer, tester and translator."]
NS.LANDING = {
    logo     = NS.Constants.LOGO,
    notes    = function() return NS.Meta("Notes") or "" end,
    sections = {
        { heading = L["Slash Commands"], rows = function() return NS.Slash:LandingRows() end },   -- from NS.COMMANDS
        { heading = L["Credits"], rows = function() return { NS.CREDITS_LINE } end },
    },
}

-- ── Master controls ─────────────────────────────────────────────────────────────────────────────
-- Composed from ONE declaration, the canonical rows in canonical order (options-ui-§15), nothing
-- omitted: the outfit bar is a real movable frame. Scale, opacity and the lock govern the bar only;
-- the docked window follows the character sheet (O14).
local DEBUG_CONSOLE_PATH = "state.debugConsole"
local TEST_MODE_PATH = "state.testMode"

--- `module.fn(...)` when the module has landed; nothing otherwise (see the file header).
local function call(module, fn, ...)
    local m = NS[module]
    if m and type(m[fn]) == "function" then return m[fn](...) end
end

local masterRows, masterTail = H.MasterControls({
    page                 = PAGE,
    addonName            = NS.BRAND,          -- the Enable row reads "Enable Ka0s Outfitter Reborn"
    debugConsolePath     = DEBUG_CONSOLE_PATH,
    minimapPath          = NS.MINIMAP_PATH,
    testModePath         = TEST_MODE_PATH,
    defaults             = {
        enabled    = D.enabled,
        visibility = D.visibility,
        scale      = D.scale,
        alpha      = D.alpha,
        locked     = D.locked,
    },
    notes                = {
        scale  = L["Applies to the outfit bar. The outfit window follows the character sheet."],
        locked = L["Locks the outfit bar."],
    },
    resetPositionTooltip = L["Moves the outfit bar back to its starting place."],
    -- The bar's place is the `bar.position` row (settings/OutfitBar.lua, P4.23); with no row yet the
    -- reset answers false and moves nothing.
    onResetPosition      = function() NS.ApplyDefault(NS.FindSchemaRow("bar.position")) end,
    onResetAll           = function() NS.ShowResetAll() end,
})

-- Rows whose storage is not a profile path: the console (session), test mode (session) and the
-- minimap button, which NS.Launcher (core/LauncherSetup.lua) owns: the row says SHOWN while the
-- stored key, LibDBIcon's own `hide`, says hidden (launcher-§3). Both launcher arms, live and
-- library-absent, read and write that one key.
local ownStorage = {
    [NS.MINIMAP_PATH] = {
        get = function() return NS.Launcher:IsShown() end,
        set = function(shown) NS.Launcher:SetShown(shown and true or false) end,
    },
    [TEST_MODE_PATH] = {
        get = function() return call("Preview", "IsActive") == true end,
        set = function(on)
            if on then call("Preview", "Start") else call("Preview", "Stop") end
        end,
    },
}
do
    local console = NS.DebugLog:ConsoleCheckbox()
    ownStorage[DEBUG_CONSOLE_PATH] = { get = console.get, set = console.set }
end

-- Each composed row's reaction, attached here because the composer cannot know them.
local reactions = {
    enabled    = function(v) NS.ApplyEnabled(v) end,
    visibility = function() if NS.OnVisibilityChanged then NS.OnVisibilityChanged() end end,
    scale      = function() call("Bar", "ApplyScale") end,
    alpha      = function() call("Bar", "ApplyAlpha") end,
    locked     = function(v) call("Bar", "SetLocked", v) end,
}

for _, row in ipairs(masterRows) do
    row.onChange = reactions[row.path] or row.onChange
    local own = ownStorage[row.path]
    if own then row.get, row.set = own.get, own.set end
    -- options-ui-§15: Test mode "is ended by Reset all settings (the row declares default = false)".
    -- The composer emits the row without one, so the reset's session-row walk would skip it; the
    -- host stamps it here.
    if row.path == TEST_MODE_PATH and row.default == nil then row.default = false end
end
NS.RegisterSchemaRows(masterRows)

-- ── Skin ── (skinning-§2/§3, core/SkinSetup.lua) the skin this addon wears, per profile. The tab is
-- the library's O.AppearanceTab, which draws every row below itself (its choice grids, the Scope's
-- check boxes, the Font and texture dropdowns), so each row carries `skipRender`; they stay schema
-- rows so the defaults resolve, every reset reaches them, and `/of get|set skin.skin` validates
-- against `values`. Their group is the tab's key, so the tab takes the group's place in the strip:
-- after Master controls (and, from P4.23, Behavior and Tooltips), before Keybindings.
--
-- Each onChange applies ONLY its own half (core/SkinSetup.lua says why): the tab and another addon's
-- "Copy to every Ka0s addon" call Skin:SetChoice before they write, so the write is a no-op, and a
-- bare `/of set` still repaints.
local SKIN_TAB = H.AppearanceTab({ owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice })
local SKIN = SKIN_TAB.key
local SD = D.skin

--- A validator for a row whose value is one of `options`' values.
local function oneOf(options)
    return function(v)
        for _, o in ipairs(options) do if o.value == v then return true end end
        return false
    end
end

NS.RegisterSchemaRows({
    { path = "skin.source", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Skin source"], default = SD.source, values = NS.SKIN_SOURCE_OPTIONS,
      validate = oneOf(NS.SKIN_SOURCE_OPTIONS),
      tooltip = L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."],
      onChange = function(v) NS.ApplySkinChoice(v, nil) end },
    { path = "skin.skin", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Skin"], default = SD.skin, values = NS.SKIN_OPTIONS, validate = oneOf(NS.SKIN_OPTIONS),
      tooltip = L["The Ka0s skin this addon wears. Changes every window and panel right away."],
      onChange = function(v) NS.ApplySkinChoice(nil, v) end },
    -- The Scope's two exceptions (LibKa0s-Skin-1.0 minor 5).
    { path = "skin.ignorePanel", page = PAGE, group = SKIN, type = "bool", skipRender = true,
      label = L["Ignore settings panel"], default = SD.ignorePanel,
      tooltip = L["Keep this addon's settings panel in the game's own look. Its windows still wear the skin."],
      onChange = function(v) NS.ApplySkinIgnore(v, nil) end },
    { path = "skin.ignoreFonts", page = PAGE, group = SKIN, type = "bool", skipRender = true,
      label = L["Ignore fonts"], default = SD.ignoreFonts,
      tooltip = L["Keep every font in this addon as the game draws it. The skin still colors the text."],
      onChange = function(v) NS.ApplySkinIgnore(nil, v) end },
    -- The Font and texture overrides (LibKa0s-Skin-1.0 minor 6): free text, not a list of `values`,
    -- because a media pack may register its keys after this file loads and `/of set` takes any key;
    -- "" is the skin's own.
    { path = "skin.font", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Font"], default = SD.font,
      tooltip = L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."],
      onChange = function(v) NS.ApplySkinOverride(v, nil) end },
    { path = "skin.texture", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Texture"], default = SD.texture,
      tooltip = L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."],
      onChange = function(v) NS.ApplySkinOverride(nil, v) end },
    -- The Font outline (LibKa0s-Skin-1.0 minor 9): where the skin outlines this addon's text. The
    -- library's three modes, in its order, so `/of set skin.outline` validates against them.
    { path = "skin.outline", page = PAGE, group = SKIN, type = "string", skipRender = true,
      label = L["Font outline"], default = SD.outline, values = NS.SKIN_OUTLINE_OPTIONS,
      validate = oneOf(NS.SKIN_OUTLINE_OPTIONS),
      tooltip = L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."],
      onChange = function(v) NS.ApplySkinOutline(v) end },
    -- The first-run skin picker's memory: set when the picker closes, so it shows once per profile.
    -- Drawn by nothing; a reset puts it back to false.
    { path = "skin.pickerSeen", page = PAGE, group = SKIN, type = "bool", skipRender = true,
      label = L["Skin picker seen"], default = SD.pickerSeen,
      tooltip = L["Whether the first-run skin picker was closed on this profile."] },
})

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then return nil end
    local ctx = H.CreatePanel("OutfitterRebornGeneralPanel", L["General"], {
        pageKey         = PAGE,
        defaultsButton  = true,
        -- A page reset (options-ui-§13). Defaults never reaches a key: the game keeps them, not the
        -- profile (options-ui-§20).
        defaultsTooltip = L["Restore every General setting on this profile to its addon default: Master controls and the skin."]
            .. " " .. H.KEYBINDS_UNCHANGED,
    })
    ctx.panel.defaultsOnClick = function() H.RestoreDefaults(PAGE, ctx) end
    -- Every page renders through the tabbed renderer (options-ui-§13). The Keybindings tab is a host
    -- tab the library draws from NS.BINDINGS (core/LauncherSetup.lua); with no `before` it is the
    -- strip's last, after every schema tab (options-ui-§20). Read here, at the page's first show.
    -- The Skin tab is keyed by its rows' group, so it takes that group's place, before Keybindings.
    local tabs = { SKIN_TAB, H.KeybindingsTab({ bindings = NS.BINDINGS or {} }) }
    H.SetRenderer(ctx, function(c)
        H.ClearScroll(c)
        H.RenderTabbedSchema(c, PAGE, { [H.MASTER_GROUP] = masterTail }, nil, { tabs = tabs })
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
end

NS.RegisterOptionsPage(PAGE, L["General"], build)
