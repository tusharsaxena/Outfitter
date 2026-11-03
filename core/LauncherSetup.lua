local addonName, NS = ...
-- core/LauncherSetup.lua — the ONE LibDataBroker launcher, registered twice (minimap button and broker
-- row) through LibKa0s-Launcher-1.0, the 14 key-binding buttons (launcher-§6, design §4.4), NS.BINDINGS,
-- the one table they are declared in, and NS.WearBoundOutfit, the ten wear keys' handler (design §4.5).
--
-- CALLS (at call time): NS.Dock.Toggle, NS.Stack.WearBound, NS.RunVerb (settings/Slash.lua), NS.Print.
-- Players' old Outfitter key assignments do not carry over (H11): the names below are new.

local Launcher = LibStub and LibStub("LibKa0s-Launcher-1.0", true)
local L = NS.L

local function minimapTable()
    local db = NS.db
    return db and db.global and db.global.minimap or nil
end

--- THE Show window handler: the launcher menu's entry and the Show window key both call it, so the
--- press and the menu cannot differ (launcher-§6). It shows or hides the outfit window (P4.19).
local function toggleWindow()
    NS.Dock.Toggle(true)
end

--- The menu's Locked entry runs the `lock` or `unlock` verb, so the menu and the verb are one handler
--- (launcher-§2, slash-commands-§8).
local function toggleLock()
    return NS.RunVerb(NS.GetSetting("locked") and "unlock" or "lock")
end

--- THE wear keys' handler (design §4.4). NS.Stack.WearBound owns the anti-panic rule and the wear: a
--- Complete outfit is worn now, anything else toggles now, and the press clears the trigger's
--- Disabled and is a hardware event. An ignored repeat says nothing; an unbound key says so. With
--- `equip.announceKeys` on, the result goes to the error frame in the outfit color (INV §5).
--- @param n number  the key, 1..10
function NS.WearBoundOutfit(n)
    local line = NS.StoodDownRefusal()        -- the button asked already; a direct caller has not
    if line then return NS.Print(line) end
    local worn, rec, ignored = NS.Stack.WearBound(n)
    if ignored then return end
    if not rec then return NS.Print(L["No outfit is bound to key %d."]:format(n)) end
    if NS.GetSetting("equip.announceKeys") == false then return end
    local c = NS.Constants.OUTFIT_MESSAGE_COLOR
    local text = (worn and L["%s equipped"] or L["%s unequipped"]):format(tostring(rec.name))
    _G.UIErrorsFrame:AddMessage(text, c.r, c.g, c.b)
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
for n = 1, 10 do
    BUTTONS[#BUTTONS + 1] = {
        name    = "OutfitterRebornWearOutfit" .. n,
        handler = function() NS.WearBoundOutfit(n) end,
        label   = L["Wear outfit %d"]:format(n),
        tooltip = L["Wears the outfit you gave key %d in its menu. A Complete outfit is put on again; any other is taken off if it is worn."]:format(n),
    }
end
BUTTONS[#BUTTONS + 1] = {
    name    = "OutfitterRebornAutoOn",
    handler = function() NS.RunVerb("auto", "on") end,
    label   = L["Turn on automatic outfit changes"],
    tooltip = L["Lets outfits with a trigger equip themselves again, as /of auto on does."],
}
BUTTONS[#BUTTONS + 1] = {
    name    = "OutfitterRebornAutoOff",
    handler = function() NS.RunVerb("auto", "off") end,
    label   = L["Turn off automatic outfit changes"],
    tooltip = L["Stops every trigger, as /of auto off does. Outfits you wear by hand are unaffected."],
}
BUTTONS[#BUTTONS + 1] = {
    name    = "OutfitterRebornUpdateOutfit",
    handler = function() NS.RunVerb("update", "") end,
    label   = L["Update outfit to equipped items"],
    tooltip = L["Saves what you are wearing into the current Complete outfit, as /of update does."],
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
    -- Test mode lands in P4.22; until then it answers off and does nothing. Show window toggles the
    -- outfit window (toggleWindow above).
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
