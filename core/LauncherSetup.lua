local addonName, NS = ...
-- core/LauncherSetup.lua — the ONE LibDataBroker launcher, registered twice (minimap button and broker
-- row) through LibKa0s-Launcher-1.0, the key-binding buttons (launcher-§6, design §4.4) and NS.BINDINGS,
-- the one table they are declared in (design §4.5).
--
-- P3 C13 lands the Show window binding only. P4.24 adds the other 13 rows to BUTTONS below (the ten
-- wear keys, AutoOn, AutoOff, UpdateOutfit) and NS.WearBoundOutfit; P4.19 points toggleWindow at
-- NS.Dock.Toggle.

local Launcher = LibStub and LibStub("LibKa0s-Launcher-1.0", true)
local L = NS.L

local function minimapTable()
    local db = NS.db
    return db and db.global and db.global.minimap or nil
end

--- THE Show window handler: the launcher menu's entry and the Show window key both call it, so the
--- press and the menu cannot differ (launcher-§6). The outfit window lands in P4.19; until then it
--- opens the settings panel, the one surface the scaffold has.
local function toggleWindow()
    NS.OpenOptionsPanel()
end

--- Run a verb by name, or `fallback` while the verb is not in NS.COMMANDS yet. `lock` and `unlock`
--- arrive with the outfit verbs in P4.24; until then the menu's Locked entry writes the one setting
--- those verbs write, through the same seam.
local function runVerbOr(verb, fallback)
    for _, entry in ipairs(NS.COMMANDS or {}) do
        if entry[1] == verb then return entry[3]("") end
    end
    return fallback()
end

local function toggleLock()
    local locked = NS.GetSetting("locked") == true
    return runVerbOr(locked and "unlock" or "lock", function() NS.SetByPath("locked", not locked) end)
end

-- ── The key bindings (launcher-§6, design §4.4) ─────────────────────────────────────────────────
-- Each button is plain, named, hidden and NOT secure, registered for the down edge only, and its
-- click asks the one refusal helper first (slash-commands-§7, "Which refusal, by hold"): a press
-- while stood down prints the line the verb would and runs nothing. Then it runs the SAME handler
-- its verb and menu entry run. THE NAMES ARE PERMANENT: the client stores the player's key against
-- them, so a rename unbinds every key. One row per button, in Bindings.xml's order, Show window first.
local BUTTONS = {
    { name    = "OutfitterRebornToggleWindow",
      handler = toggleWindow,
      label   = L["Toggle outfit window"],
      tooltip = L["Shows or hides the outfit window, as the launcher's Show window entry does."] },
}

local function clickCommand(button) return "CLICK " .. button .. ":LeftButton" end

-- The category's title is the brand, assigned at file scope because the client reads it when it
-- registers the bindings (launcher-§6). The brand never goes through L, so no overlay can change it
-- (launcher-§1, anti-patterns #84).
rawset(_G, "BINDING_HEADER_OUTFITTERREBORN", NS.BRAND)

-- The ONE bindings table (launcher-§6): the General page's Keybindings tab draws its rows from it
-- (options-ui-§20) and the suite checks Bindings.xml against it.
NS.BINDINGS = {}
for _, spec in ipairs(BUTTONS) do
    local handler = spec.handler
    local button = CreateFrame("Button", spec.name, UIParent)
    button:RegisterForClicks("AnyDown")
    button:SetScript("OnClick", function()
        local line = NS.StoodDownRefusal()
        if line then return NS.Print(line) end
        return handler()
    end)
    button:Hide()
    local command = clickCommand(spec.name)
    NS.BINDINGS[#NS.BINDINGS + 1] = { command = command, tooltip = spec.tooltip }
    -- The label's global name holds a space and a colon, so no identifier can spell it: rawset.
    rawset(_G, "BINDING_NAME_" .. command, spec.label)
end

if not Launcher then
    -- Degrade, never error: no button and no broker row, said once, and the Minimap button row still
    -- reads and writes LibDBIcon's own `hide` key so the setting survives the next healthy load.
    local missing = NS.LIBKA0S_MISSING .. ", so there is no minimap button and no broker plugin."
    local announced = false
    NS.Launcher = {
        Register = function()
            if not announced then
                announced = true
                NS.Print(missing)
            end
            return false
        end,
        IsRegistered = function() return false end,
        Object       = function() return nil end,
        IsShown      = function()
            local t = minimapTable()
            return not (t and t.hide)
        end,
        SetShown     = function(_, shown)
            local t = minimapTable()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = Launcher:New({
    name    = addonName,                   -- the registration name LibDBIcon keys the position by
    icon    = NS.Constants.LOGO_128,
    label   = NS.BRAND,                    -- the brand in plain text, never L or the TOC Title (launcher-§1)
    minimap = minimapTable,                -- db.global.minimap, shared with the Minimap button row
    -- Left-click ALWAYS opens the settings panel; right-click the library's options menu (launcher-§2):
    -- Enabled, Locked, Test mode, Show window, Open settings, Open skin selector. No Sim row (H18).
    -- Each toggle calls the same handler its verb or key calls, never a copy, and the library grays
    -- every entry but Enabled while the addon is disabled. The icon and label are static (H6).
    openSettings   = function() NS.OpenOptionsPanel() end,
    openSkinPicker = function() if NS.RunSkinVerb then NS.RunSkinVerb() end end,
    isEnabled      = function() return not NS.IsDisabled() end,
    setEnabled     = function(on) NS.RunVerb(on and "enable" or "disable") end,
    isLocked       = function() return NS.GetSetting("locked") == true end,
    toggleLock     = toggleLock,
    -- Test mode and the outfit window land in P4.22 and P4.19; until then the first answers off and
    -- does nothing, and Show window opens the settings panel (toggleWindow above).
    isTestMode     = function() return NS.Preview ~= nil and NS.Preview.IsActive() end,
    toggleTestMode = function() if NS.Preview then NS.Preview.Toggle() end end,
    isWindowShown  = function() return NS.Dock ~= nil and NS.Dock.IsShown() end,
    toggleWindow   = toggleWindow,
    -- The one host line: the outfit on top of the stack. The stack lands in P4.9; until then the
    -- tooltip carries the library's status block only.
    onTooltipShow  = function(tt)
        if NS.Stack then tt:AddLine(L["Current outfit: %s"]:format(NS.Stack.CurrentLabel())) end
    end,
    version        = function() return NS.Version() end,
    print          = function(line) NS.Print(line) end,
    debug          = function(tag, message) NS.Debug(tag, "%s", message) end,
    debugAtEnable  = function(tag, message) NS.DebugAtEnable(tag, "%s", message) end,
})
