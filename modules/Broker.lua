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
--                 brand and the default outfit icon (132724) in white. A fileID icon is cropped
--                 (iconCoords) as the window's art is; a glyph is drawn whole
--   hover         the outfit menu, dropped under the object (Forever smoke feedback 3, owner
--                 2026-11-09: what left-click opened before): the brand, Open outfit window
--                 (NS.Dock.Open: an open, never a close), Automatic changes (the `auto` verb), then
--                 each category in the window's order with one toggle row per visible outfit (not
--                 Disabled, not hidden from the bar: the legacy OutfitIsVisible), and the two click
--                 hints. It closes once the pointer has been off both the object and the menu for
--                 HOVER_GRACE seconds
--   left-click    the character sheet with the outfit window open (NS.Dock.Open)
--   right-click   the settings (NS.OpenOptionsPanel)
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

-- A fileID's crop, the window's item-art zoom (S.IconBorder's 0.07); a glyph is drawn whole.
local ART_CROP = { 0.07, 0.93, 0.07, 0.93 }

local function coordsFor(tex)
    if type(tex) == "number" then return ART_CROP end
    return nil
end

--- The default outfit icon, untinted (smoke round 2 design G1).
local function idleIcon()
    return NS.Constants.DEFAULT_OUTFIT_ICON, 1, 1, 1
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
    object.iconCoords = coordsFor(tex)
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

-- The right-click: the settings.
local function openSettings()
    NS.OpenOptionsPanel()
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
    root:CreateTitle(L["Left-click: outfit window"])
    root:CreateTitle(L["Right-click: settings"])
end

-- ── the object's scripts ────────────────────────────────────────────────────────────────────

-- The hover menu's close: off the object and the menu for this long (seconds).
local HOVER_GRACE = 0.3
local watcher, hoverFrom, hoverMenu, away

local function stopWatch()
    hoverFrom, hoverMenu, away = nil, nil, 0
    if watcher then watcher:Hide() end
end

local function over(f)
    return type(f) == "table" and type(f.IsMouseOver) == "function" and f:IsMouseOver() == true
end

local function menuUp()
    return type(hoverMenu) == "table" and type(hoverMenu.IsShown) == "function" and hoverMenu:IsShown() == true
end

local function watchTick(_, elapsed)
    if not menuUp() then return stopWatch() end
    if over(hoverFrom) or over(hoverMenu) then away = 0; return end
    away = away + NS.SafeNumber(elapsed, 0)
    if away < HOVER_GRACE then return end
    local from = hoverFrom
    stopWatch()
    NS.CloseMenuFrom(function(anchor) return anchor == from end)
end

-- Hover: the outfit menu under the object, unless it is already up from it.
local function onEnter(frame)
    if menuUp() and hoverFrom == frame then return end
    local _, menu = NS.OpenMenu(frame, fill, { below = true })
    if type(menu) ~= "table" or type(menu.IsShown) ~= "function" then return end
    hoverFrom, hoverMenu, away = frame, menu, 0
    if not watcher then
        watcher = CreateFrame("Frame", nil, UIParent)
        watcher:SetScript("OnUpdate", watchTick)
    end
    watcher:Show()
end

local function onClick(_, button)
    NS.CloseMenu()
    stopWatch()
    if button == "RightButton" then return openSettings() end
    openWindow()
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
        icon          = tex, iconR = r, iconG = g, iconB = b, iconCoords = coordsFor(tex),
        OnClick       = onClick,
        OnEnter       = onEnter,
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
