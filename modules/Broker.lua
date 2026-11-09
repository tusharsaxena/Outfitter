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
-- THE SECURE CLICK (the owner's report, 2026-11-09). Opening CharacterFrame from addon code taints
-- its OnShow, and on WoW Forever that OnShow compares the player frame's secret health values
-- (F-UI Camelot/CharacterFrame.lua:710-729 -> TextStatusBar.lua:110): "attempt to compare a secret
-- number value (execution tainted by 'OutfitterReborn')". A broker display's click is addon code, so
-- the sheet is opened by the hardware click itself instead. While the pointer is on the display, out
-- of combat lockdown, an invisible SecureActionButtonTemplate button (`OutfitterRebornBrokerClick`)
-- lies over it at the display's screen rect (never anchored to the display, so no foreign frame is
-- restricted). Its left button is `type1 = "click"` on CharacterMicroButton, which runs Blizzard's
-- own ToggleCharacter("PaperDollFrame") untainted, set only while the sheet is closed. Its PostClick
-- then does the rest (NS.Dock.Open, which finds the sheet up, or the settings). It hides when the
-- pointer leaves it, at PLAYER_REGEN_DISABLED, and stood down. Without it (in lockdown, no micro
-- button) the display's own click goes through NS.Dock.Open, which on WoW Forever never opens a closed
-- sheet from addon code: it keeps the wish and says to open the sheet.
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

-- The right-click: the settings.
local function openSettings()
    NS.OpenOptionsPanel()
end

-- The left-click: the window, the sheet already up when the secure click opened it. With the sheet
-- closed and no secure click, NS.Dock.Open decides: Retail opens the sheet, WoW Forever keeps the
-- wish and says so (THE SECURE CLICK).
local function leftClick()
    local line = NS.StoodDownRefusal()
    if line then return NS.Print(line) end
    NS.Dock.Open()
end

-- The menu's Open outfit window: an open, never a close (G9 names it so). A menu row is addon code,
-- so it opens as the fallback left-click does (THE SECURE CLICK).
local openWindow = leftClick

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

local showOverlay -- the secure click's placing, defined with it below

-- Hover: the secure click over the object, and the outfit menu under it unless it is already up.
local function onEnter(frame)
    showOverlay(frame)
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
    leftClick()
end

-- ── the secure click ────────────────────────────────────────────────────────────────────────

local overlay

local function locked() return NS.Compat.InCombatLockdown() end

local function hideOverlay()
    if overlay and not locked() then overlay:Hide() end
end

local function buildOverlay()
    local o = CreateFrame("Button", "OutfitterRebornBrokerClick", UIParent, "SecureActionButtonTemplate")
    o:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    o:SetAttribute("useOnKeyDown", false)
    o:SetFrameStrata(NS.Constants.LAYERS.STRATA.POPUP)
    o:Hide()
    o:HookScript("PostClick", function(_, button) onClick(o, button) end)
    o:SetScript("OnLeave", hideOverlay)
    o:RegisterEvent("PLAYER_REGEN_DISABLED")
    o:SetScript("OnEvent", function(self) self:Hide() end)
    return o
end

-- The display's screen rect in UIParent's units, or nil before it is laid out.
local function rectOf(frame)
    local l, b = NS.SafeNumber(frame:GetLeft(), nil), NS.SafeNumber(frame:GetBottom(), nil)
    local w, h = NS.SafeNumber(frame:GetWidth(), nil), NS.SafeNumber(frame:GetHeight(), nil)
    if not (l and b and w and h) or w <= 0 or h <= 0 then return nil end
    local k = NS.SafeNumber(frame:GetEffectiveScale(), 1) / NS.SafeNumber(UIParent:GetEffectiveScale(), 1)
    return l * k, b * k, w * k, h * k
end

-- Lay the secure button over `frame`, its left button clicking the micro button while the sheet is
-- closed. Out of lockdown and standing up only.
function showOverlay(frame)
    local micro = _G.CharacterMicroButton
    if locked() or NS.IsStoodDown() or type(micro) ~= "table" or type(frame) ~= "table"
        or type(frame.GetLeft) ~= "function" then return end
    local l, b, w, h = rectOf(frame)
    if not l then return end
    overlay = overlay or buildOverlay()
    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
    overlay:SetSize(w, h)
    local open = _G.CharacterFrame:IsShown() == true
    overlay:SetAttribute("type1", (not open) and "click" or nil)
    overlay:SetAttribute("clickbutton1", (not open) and micro or nil)
    overlay:Show()
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

--- The stand-down (design §5.12): the bus record drops the receivers; the text goes to the brand,
--- and the secure click goes (queued past lockdown: it is a protected frame).
function Broker.Suspend()
    render(true)
    if overlay then NS.SecureQueue.Run("broker.overlay", function() overlay:Hide() end) end
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
