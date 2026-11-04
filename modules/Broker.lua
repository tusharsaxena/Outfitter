local _, NS = ...
-- modules/Broker.lua — NS.Broker: the Outfits data source, the old addon's outfit switcher
-- (OutfitterLDB.lua and OutfitterMinimapButton.lua at d396f11; sheet and window feedback design G9).
--
-- A SECOND LibDataBroker object, beside the launcher (core/LauncherSetup.lua), which stays exactly
-- as launcher-§1/§2 require. This one is a `data source` named OutfitterRebornOutfits (not "Outfitter",
-- which the old addon owns and may still register). It is never handed to LibDBIcon, so it shows
-- only in a broker display and the minimap keeps one button. The departure from launcher-§1's one
-- object is recorded in docs/ARCHITECTURE.md -> Documented deviations.
--
--   text / icon   the top outfit's name and its icon (NS.OutfitIcon); with none, or stood down, the
--                 brand and the coat hanger tinted as the sheet button is (`of.sheet.button`)
--   left-click    the outfit menu: the brand, Open outfit window (NS.Dock.Open: an open, never a
--                 close), Automatic changes (the `auto` verb), then each category in the window's
--                 order with one toggle row per visible outfit (not Disabled, not hidden from the
--                 bar: the legacy OutfitIsVisible)
--   right-click   the outfit window (NS.Dock.Toggle, the launcher's Show window handler's call)
--   tooltip       the brand, the current outfit and the two click hints
--
-- An outfit row's click: a modifier closes the menu and asks to set the outfit to the worn items
-- (the legacy AskSetCurrent); a worn outfit that is not Complete comes off; anything else is worn.
-- The menu stays open and repaints every row's tick (core/WidgetsSetup.lua). These are the
-- window's own calls, so a wear in combat is queued exactly as the window's is (modules/Equip.lua).
-- Stood down, the object stays, its text is the brand, and the outfit rows and Open outfit window
-- are grayed and refuse with the one line (slash-commands-§7). Automatic changes stays live: `auto`
-- is a host live verb (settings/Slash.lua).
--
-- CALLS (at call time): NS.Stack.Top/IsWorn/Wear/Remove/CurrentLabel, NS.Outfits.Get/Categories,
-- NS.WindowListModel.SortedIds/Status/LABEL, NS.WindowRows.STATUS_TOKEN, NS.OutfitIcon,
-- NS.Popups.ShowSetCurrent, NS.OpenMenu/CloseMenu, NS.IconText, NS.RunVerb, NS.Dock.Open/Toggle,
-- NS.SkinColor/SkinEscape.

local Broker = {}
NS.Broker = Broker

local L = NS.L

local NAME = "OutfitterRebornOutfits"
Broker.NAME = NAME

local COMPLETE = "Complete"

-- The launcher library serves one object by design, so the second one is LibDataBroker's own.
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)

local object, installed

-- ── text and icon ───────────────────────────────────────────────────────────────────────────

--- The coat hanger in the sheet button's tint (its owner token, Ka0s gold under Ka0s Default).
local function idleIcon()
    local r, g, b = NS.SkinColor("of.sheet.button")
    if r == nil then r, g, b = unpack(NS.Constants.SHEET_BUTTON_TINT) end
    return NS.Constants.DEFAULT_OUTFIT_ICON, r, g, b
end

--- Write the object's text and icon. `down` is the latch's state as the caller knows it: the
--- lifecycle's own walks pass it, because the latch may not have flipped yet while they run.
--- @param down boolean
local function render(down)
    if not object then return end
    local id = not down and NS.Stack.Top() or nil
    local rec = id and NS.Outfits.Get(id)
    local name = rec and rec.name
    local tex, r, g, b
    if type(name) == "string" and name ~= "" then
        object.text = name
        tex, r, g, b = NS.OutfitIcon(rec)
    else
        object.text = NS.BRAND
        tex, r, g, b = idleIcon()
    end
    object.icon, object.iconR, object.iconG, object.iconB = tex, r, g, b
end

--- Redraw from the latch's current state (the bus and the skin's looks-changed listener).
function Broker.Refresh()
    render(NS.IsStoodDown())
end

-- ── the menu ────────────────────────────────────────────────────────────────────────────────

--- An outfit row's label: its icon, then its name in the window's status color. The icon is the
--- library's cropped inline markup (NS.IconText), which takes no tint: a glyph shows in white here,
--- and in its color on the object's own icon.
local function outfitLabel(id, statusCache)
    local rec = NS.Outfits.Get(id)
    local name = rec and type(rec.name) == "string" and rec.name or "?"
    local token = NS.WindowRows.STATUS_TOKEN[NS.WindowListModel.Status(id, statusCache)]
    local esc = token and NS.SkinEscape(token)
    if esc then name = esc .. name .. "|r" end
    local icon = NS.IconText((NS.OutfitIcon(rec)), 0)
    return icon ~= "" and (icon .. " " .. name) or name
end

local function modifierDown()
    return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

--- One outfit row's click (OutfitterMinimapButton.lua:59-66).
local function clickOutfit(id)
    local line = NS.StoodDownRefusal()
    if line then return NS.Print(line) end
    if modifierDown() then
        -- The prompt is a dialog of its own: the menu, kept open by a toggle row's click, goes first.
        NS.CloseMenu()
        return NS.Popups.ShowSetCurrent(id)
    end
    local rec = NS.Outfits.Get(id)
    if not rec then return end
    if rec.category ~= COMPLETE and NS.Stack.IsWorn(id) then
        NS.Stack.Remove(id, { hw = true })
    else
        NS.Stack.Wear(id, { hw = true, clearDisabled = true })
    end
end

local function isWorn(id) return NS.Stack.IsWorn(id) end

local function autoOn() return NS.GetSetting("auto.enabled") ~= false end

--- The `auto` verb's handler, so the menu and the verb cannot differ.
local function toggleAuto() NS.RunVerb("auto", autoOn() and "off" or "on") end

-- The menu's Open outfit window: an open, never a close (G9 names it so).
local function openWindow()
    local line = NS.StoodDownRefusal()
    if line then return NS.Print(line) end
    NS.Dock.Open()
end

-- The right-click: the launcher's Show window toggle, which closes the sheet with the window.
local function toggleWindow()
    local line = NS.StoodDownRefusal()
    if line then return NS.Print(line) end
    NS.Dock.Toggle(true)
end

--- Whether an outfit is on the menu: the legacy OutfitIsVisible (Outfitter.lua:2452 at d396f11), not
--- Disabled (its trigger off, design §3.3) and not hidden from the bar, the rule Bar.LiveSource keeps.
local function listed(id)
    local rec = NS.Outfits.Get(id)
    if not rec then return false end
    local off = rec.trigger and rec.trigger.disabled
    local hidden = rec.bar and rec.bar.hide
    return not off and not hidden
end

--- The listed outfits of a category, in the window's order.
local function listedIds(cat)
    local out = {}
    for _, id in ipairs(NS.WindowListModel.SortedIds(cat)) do
        if listed(id) then out[#out + 1] = id end
    end
    return out
end

--- The menu, written against MenuUtil's description (core/WidgetsSetup.lua). A category with no
--- listed outfit has no title here: the menu lists outfits to wear, not the window's headers.
local function fill(root)
    local down = NS.IsStoodDown()
    root:CreateTitle(NS.BRAND)
    local open = root:CreateButton(L["Open outfit window"], openWindow)
    if down then open:SetEnabled(false) end
    root:CreateCheckbox(L["Automatic changes"], autoOn, toggleAuto)
    local LM, statusCache = NS.WindowListModel, {}
    for _, cat in ipairs(NS.Outfits.Categories()) do
        local ids = listedIds(cat)
        if #ids > 0 then
            root:CreateTitle(LM.LABEL[cat] or tostring(cat))
            for _, id in ipairs(ids) do
                local row = root:CreateCheckbox(outfitLabel(id, statusCache), isWorn, clickOutfit, id)
                if down then row:SetEnabled(false) end
            end
        end
    end
end

-- ── the object's scripts ────────────────────────────────────────────────────────────────────

local function onClick(frame, button)
    if button == "RightButton" then return toggleWindow() end
    NS.OpenMenu(frame, fill)
end

local function onTooltipShow(tt)
    tt:AddLine(NS.BRAND)
    tt:AddLine(L["Current outfit: %s"]:format(NS.Stack.CurrentLabel()))
    local line = NS.StoodDownRefusal()
    if line then return tt:AddLine(line) end
    tt:AddLine(L["Left-click: choose an outfit"])
    tt:AddLine(L["Right-click: outfit window"])
end

--- The registered object, or nil without LibDataBroker.
--- @return table|nil
function Broker.Object()
    return object
end

if LDB then
    local tex, r, g, b = idleIcon()
    object = LDB:NewDataObject(NAME, {
        type          = "data source",
        label         = NS.BRAND .. ": " .. L["Outfits"],
        text          = NS.BRAND,
        icon          = tex, iconR = r, iconG = g, iconB = b,
        OnClick       = onClick,
        OnTooltipShow = onTooltipShow,
    })
else
    NS.Debug("Broker", "LibDataBroker-1.1 is not loaded, so there is no Outfits broker object")
end

-- ── lifecycle ───────────────────────────────────────────────────────────────────────────────

local REDRAW_ON = { "OUTFIT_WORN", "OUTFIT_REMOVED", "STACK_CHANGED", "OUTFIT_EDITED", "OUTFIT_RENAMED",
                    "OUTFIT_DELETED" }

--- The stand-down (design §5.12): the bus record drops the receivers; the text goes to the brand.
function Broker.Suspend()
    render(true)
end

--- The stand-up: the receivers (once per session; the bus record replays them) and the redraw.
function Broker.Resume()
    if object and not installed then
        installed = true
        NS.Skin.OnLooksChanged(Broker.Refresh)
        local bus = NS.NewBusTarget()
        if bus then
            for _, key in ipairs(REDRAW_ON) do bus:RegisterMessage(NS.MSG[key], Broker.Refresh) end
        end
    end
    render(false)
end
