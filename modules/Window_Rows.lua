local _, NS = ...
-- modules/Window_Rows.lua — NS.WindowRows: the outfit list's 14 rows and the secure child each one owns
-- (design §7.3, INV §7.2, §16.3).
--
-- FIXED AND VIRTUALIZED. All 14 rows are built once, in Rows.Build, which runs only from Dock.Refresh
-- and so only out of combat. Scrolling binds another entry to the same row; a row is never re-anchored,
-- re-parented, shown or hidden after build, and a blank row is one whose `entry` is nil. Its regions
-- (the chevron, the name, the worn box, the icons, the marks) are shown and hidden per kind: none is
-- protected.
--
-- AN OUTFIT ROW (sheet and window feedback design G4), left to right: the worn box, the outfit's icon,
-- the Equipment Manager mark (that tab's own icon, full when the outfit is stored there, dimmed when
-- not; a click toggles it), the name, the automation lightning and the gear that opens the menu.
--
-- THE SECURE CHILD. Each row owns `<row>Secure`, a SecureActionButtonTemplate button covering it, so
-- an item-targeting spell (Disenchant) lands on a secure frame (UseContainerItem is protected). Its
-- hooks call the row's own handlers (Outfitter.lua:8423-8444).
--   Never re-parent it and never touch its anchors: the client refuses every SetPoint an insecure
--   caller makes on a protected frame ("Cannot anchor protected frames to regions"), so the
--   SetAllPoints anchor made at birth is the only one this button will ever have, and dropping it
--   can't be undone. The character sheet is kept clear of these buttons by moving the whole window
--   instead (modules/Dock.lua).
-- Arming and disarming are no-ops in combat lockdown. Disarm runs before a row goes blank, on every
-- render, and at PLAYER_REGEN_DISABLED (modules/Dock.lua).
--
-- CALLS (at call time; design §12): NS.Window.MarkDirty/ToggleCollapsed, NS.Stack.Wear/Remove/IsWorn/
-- Select/Selected, NS.Outfits.Get/IsEM, NS.EM.StoreOnServer/StoreLocally, NS.OutfitMenu.Open,
-- NS.OutfitTooltip.Show, NS.OutfitIcon (the one icon resolver), NS.Compat (pickup, use, sell
-- cursor, item icon).

local Rows = { rows = {}, built = false, COUNT = 14, ROW_H = 18, ROW_W = 228 }
NS.WindowRows = Rows

local L = NS.L
local LEVEL = NS.Constants.LAYERS.LEVEL
local Secrets = NS.Secrets

-- The status -> owner color token of an outfit's name (design §7.1); "normal" draws the body color.
local STATUS_TOKEN = { disabled = "of.outfit.disabled", missing = "of.outfit.missing", banked = "of.outfit.banked" }
Rows.STATUS_TOKEN = STATUS_TOKEN

local DIM_ALPHA = 0.4
local BUYBACK_TAB = 2

-- The Equipment Manager mark's alpha for an outfit the Equipment Manager does not hold (design G4).
local EM_DIM_ALPHA = 0.35
-- The sheet's sidebar tab whose icon the mark draws: the Equipment Manager's, third in
-- PAPERDOLL_SIDEBARS (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/
-- PaperDollFrame.lua:79, :97-100). Read when the rows are built, so the client's art is the art drawn.
local EM_SIDEBAR_TAB = 3

-- An outfit's icon -> texture, r, g, b: the one resolver the bar and the broker draw too (plan Task 3.5).
local function outfitIcon(rec)
    return NS.OutfitIcon(rec)
end

local function locked() return NS.Compat.InCombatLockdown() end

-- ── arming ────────────────────────────────────────────────────────────────────────────────────

--- Hide one row's secure child: hiding it is all this file ever does to it once it is born.
--- @param row table
function Rows.Disarm(row)
    if locked() then return end
    row.secure:Hide()
end

--- Every row's.
function Rows.DisarmSecure()
    for _, row in ipairs(Rows.rows) do Rows.Disarm(row) end
end

--- An item row shows its secure child, aimed at the item's bag slot; any other row hides it
--- (Outfitter.lua:8467-8494).
--- @param row table
function Rows.ArmSecure(row)
    if locked() then return end
    local s, e = row.secure, row.entry
    if not (e and e.kind == "item") then
        s:Hide()
        return
    end
    local loc = e.item.loc or {}
    s:SetAttribute("type", nil)
    s:SetAttribute("target-bag", loc.bag)
    s:SetAttribute("target-slot", loc.slot)
    s:Show()
end

-- ── clicks ────────────────────────────────────────────────────────────────────────────────────

local function clientTruth(name)
    local fn = _G[name]
    if type(fn) ~= "function" then return false end
    return Secrets.PlainTruth(fn()) == true
end

local function spellTargeting()
    return clientTruth("SpellCanTargetItem") or clientTruth("SpellCanTargetItemID")
end

-- The merchant's buyback tab is open: a right click there must not sell (read only).
local function onBuyback()
    local m = MerchantFrame
    return m ~= nil and m:IsShown() == true and m.selectedTab == BUYBACK_TAB
end

local CLICK = {}
function CLICK.category(_, e) NS.Window.ToggleCollapsed(e.id) end
function CLICK.outfit(row, e, button)
    if button == "LeftButton" then
        NS.Stack.Wear(e.id, { hw = true, clearDisabled = true })
    else
        NS.OutfitMenu.Open(row, e.id)
    end
end
function CLICK.item(_, e, button)
    local loc = e.item.loc or {}
    if button == "LeftButton" then
        NS.Compat.PickupItemLocation(loc)
    elseif not onBuyback() and loc.bag then
        NS.Compat.UseContainerItem(loc.bag, loc.slot)
    end
end

--- PreClick: a spell targeting an item makes the click the secure button's (Outfitter.lua:8688).
function Rows.PreClick(row)
    row.usingSpell = spellTargeting()
end

--- PostClick, from the row or its secure child (whichever took the click).
--- @param row table
--- @param button string
function Rows.OnClick(row, button)
    if NS.IsStoodDown() then return end
    local spell = row.usingSpell
    row.usingSpell = nil
    local e = row.entry
    if spell or not e then return end
    CLICK[e.kind](row, e, button)
    NS.Window.MarkDirty(true)
end

local function onWornClick(row)
    local e = row.entry
    if NS.IsStoodDown() or not (e and e.kind == "outfit") then return end
    if row.worn:GetChecked() then
        NS.Stack.Wear(e.id, { hw = true, clearDisabled = true })
    else
        NS.Stack.Remove(e.id, { hw = true })
    end
    NS.Window.MarkDirty(true)
end

-- The EM mark (INV §3.5 OutfitServerButton): the first click on an outfit that is not selected only
-- selects it; a click on the selected one stores it on the server. A click on the full mark (an
-- outfit the Equipment Manager holds) stores it locally.
local function storeOnServer(id)
    local St = NS.Stack
    if St.Selected() ~= id then
        St.Wear(id, { hw = true, clearDisabled = true })
        St.Select(id)
        return
    end
    local ok, popupKey = NS.EM.StoreOnServer(id)
    if not ok and popupKey then StaticPopup_Show(popupKey) end
end

local function onEmClick(row)
    local e = row.entry
    if NS.IsStoodDown() or not (e and e.kind == "outfit") then return end
    if locked() then
        NS.Print(L["Outfits can't be changed in combat."])
        return
    end
    if NS.Outfits.IsEM(e.id) then
        NS.EM.StoreLocally(e.id)
    else
        storeOnServer(e.id)
    end
    NS.Window.MarkDirty(true)
end

-- ── hover ─────────────────────────────────────────────────────────────────────────────────────

local function itemTooltip(row, item)
    local loc = item.loc or {}
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if loc.bag then
        GameTooltip:SetBagItem(loc.bag, loc.slot)
        if MerchantFrame and MerchantFrame:IsShown() then NS.Compat.ShowContainerSellCursor(loc.bag, loc.slot) end
    elseif loc.slotID then
        GameTooltip:SetInventoryItem("player", loc.slotID)
    end
    GameTooltip:Show()
end

local HOVER = {}
function HOVER.category(row, e)
    if not e.desc then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(e.label)
    GameTooltip:AddLine(e.desc, nil, nil, nil, true)
    GameTooltip:Show()
end
function HOVER.outfit(row, e)
    if not NS.OutfitTooltip.Show(e.id, row, "ANCHOR_RIGHT") then GameTooltip:Hide() end
end
function HOVER.item(row, e) itemTooltip(row, e.item) end

function Rows.OnEnter(row)
    local e = row.entry
    if NS.IsStoodDown() or not e then return end
    HOVER[e.kind](row, e)
end

function Rows.OnLeave()
    GameTooltip:Hide()
end

-- ── render ────────────────────────────────────────────────────────────────────────────────────

local REGIONS = { "chevron", "label", "name", "itemName", "icon", "outfitIcon", "worn", "em", "trig", "menu" }

local RENDER = {}
function RENDER.category(row, e)
    row.chevron:SetTexture(NS.Icon(e.collapsed and "chevron-right" or "chevron-down"))
    row.chevron:Show()
    row.label:SetText(e.label)
    row.label:Show()
end

function RENDER.outfit(row, e)
    local O, rec = NS.Outfits, NS.Outfits.Get(e.id)
    if not rec then return end
    row.worn:SetChecked(NS.Stack.IsWorn(e.id))
    row.worn:Show()
    local tex, r, g, b = outfitIcon(rec)
    row.outfitIcon:SetTexture(tex)
    row.outfitIcon:SetVertexColor(r, g, b)
    row.outfitIcon:Show()
    row.em:SetAlpha(O.IsEM(e.id) and 1 or EM_DIM_ALPHA)
    row.em:Show()
    local name = type(rec.name) == "string" and rec.name or ""
    if e.status == "disabled" then name = L["%s (Disabled)"]:format(name) end
    row.name:SetText(name)
    NS.Skin.Text(row.name, STATUS_TOKEN[e.status] or "body")
    row.name:Show()
    local trigger = rec.trigger
    if trigger and trigger.id then
        local dim = NS.GetSetting("auto.enabled") == false or trigger.disabled == true
        row.trig:SetAlpha(dim and DIM_ALPHA or 1)
        row.trig:Show()
    end
    row.menu:Show()
end

function RENDER.item(row, e)
    local item = e.item
    row.icon:SetTexture(NS.Compat.ItemIcon(item.id))
    row.icon:Show()
    row.itemName:SetText(item.name or "")
    -- No quality color (an item the client has not cached yet): the muted text color, always set, so
    -- a reused row never keeps the last item's color (the legacy drew it GRAY_FONT_COLOR).
    local r, g, b = NS.QualityColor(item.quality)
    if r == nil then r, g, b = NS.SkinColor("text.muted") end
    row.itemName:SetTextColor(r, g, b)
    row.itemName:Show()
end

--- Bind `entry` (nil = blank) to `row`: disarm first, then draw, then arm an item row.
--- @param row table
--- @param entry table|nil
--- @param index number  the entry's position in the list (the stripe)
function Rows.Bind(row, entry, index)
    Rows.Disarm(row)
    row.entry = entry
    for _, key in ipairs(REGIONS) do row[key]:Hide() end
    if entry then RENDER[entry.kind](row, entry) end
    local selected = entry ~= nil and entry.kind == "outfit" and entry.id == NS.Stack.Selected()
    NS.Skin.ListRow(row, { stripe = (index or 0) % 2 == 1, selected = selected })
    if entry and entry.kind == "item" then Rows.ArmSecure(row) end
end

-- ── build ─────────────────────────────────────────────────────────────────────────────────────

local function checkbox(row, suffix, x)
    local cb = CreateFrame("CheckButton", row.__rowName .. suffix, row)
    cb:SetSize(16, 16)
    cb:SetPoint("LEFT", row, "LEFT", x, 0)
    NS.Skin.Checkbox(cb, { hover = true })
    return cb
end

local function regions(row)
    local S = NS.Skin
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.chevron:SetSize(12, 12)
    row.chevron:SetPoint("LEFT", row, "LEFT", 2, 0)
    S.Mark(row.chevron)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 18, 0)
    row.label:SetJustifyH("LEFT")
    S.Text(row.label, "heading")
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row, "LEFT", 68, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -38, 0)
    row.name:SetJustifyH("LEFT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 14, 0)
    S.IconBorder(row.icon, { fromSkin = true })
    -- An outfit's icon is Blizzard art too (a fileID today), so it is edged as the item's is.
    row.outfitIcon = row:CreateTexture(nil, "ARTWORK")
    row.outfitIcon:SetSize(16, 16)
    row.outfitIcon:SetPoint("LEFT", row, "LEFT", 32, 0)
    S.IconBorder(row.outfitIcon, { fromSkin = true })
    row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemName:SetPoint("LEFT", row, "LEFT", 34, 0)
    row.itemName:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.itemName:SetJustifyH("LEFT")
    row.trig = row:CreateTexture(nil, "ARTWORK")
    row.trig:SetSize(12, 12)
    row.trig:SetPoint("RIGHT", row, "RIGHT", -22, 0)
    row.trig:SetTexture(NS.Icon("ph:lightning"))
    S.Mark(row.trig, { token = "of.row.trigger" })
end

-- The Equipment Manager mark: a plain button drawing that sidebar tab's icon, unskinned (it is the
-- tab's own art, a sprite sheet, never cropped or edged as an item icon is).
local function emMark(row)
    local em = CreateFrame("Button", row.__rowName .. "EM", row)
    em:SetSize(16, 16)
    em:SetPoint("LEFT", row, "LEFT", 50, 0)
    em.icon = em:CreateTexture(nil, "ARTWORK")
    em.icon:SetAllPoints(em)
    local tabs = _G.PAPERDOLL_SIDEBARS
    local tab = type(tabs) == "table" and tabs[EM_SIDEBAR_TAB]
    if type(tab) == "table" then
        em.icon:SetTexture(tab.icon)
        if type(tab.texCoords) == "table" then em.icon:SetTexCoord(unpack(tab.texCoords)) end
    end
    em:SetScript("OnClick", function() onEmClick(row) end)
    em:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Stored in the Equipment Manager"])
        GameTooltip:Show()
    end)
    em:SetScript("OnLeave", Rows.OnLeave)
    return em
end

-- The menu control: a borderless gear (design G4, G10).
local function gearMenu(row)
    local menu = CreateFrame("Button", row.__rowName .. "Menu", row)
    menu:SetSize(14, 14)
    menu:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    menu.icon = menu:CreateTexture(nil, "ARTWORK")
    menu.icon:SetAllPoints(menu)
    menu.icon:SetTexture(NS.Icon("ph:gear-six"))
    NS.Skin.Button(menu, { noBg = true, noBorder = true })
    menu:SetScript("OnClick", function()
        local e = row.entry
        if NS.IsStoodDown() or not (e and e.kind == "outfit") then return end
        NS.OutfitMenu.Open(menu, e.id)
    end)
    return menu
end

local function controls(row)
    row.worn = checkbox(row, "Worn", 14)
    row.worn:SetScript("OnClick", function() onWornClick(row) end)
    row.em = emMark(row)
    row.menu = gearMenu(row)
end

-- The secure child: SetAllPoints at birth, its hooks wired to the row's handlers, hidden.
local function secureChild(row)
    local s = CreateFrame("Button", row.__rowName .. "Secure", row, "SecureActionButtonTemplate")
    s:SetAllPoints(row)
    s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    s:SetAttribute("useOnKeyDown", false)
    s:HookScript("PreClick", function() Rows.PreClick(row) end)
    s:HookScript("PostClick", function(_, button) Rows.OnClick(row, button) end)
    s:HookScript("OnEnter", function() Rows.OnEnter(row) end)
    s:HookScript("OnLeave", Rows.OnLeave)
    s:Hide()
    row.secure = s
end

local function newRow(list, i)
    local name = "OutfitterRebornListRow" .. i
    local row = CreateFrame("Button", name, list)
    row.__rowName = name
    row:SetSize(Rows.ROW_W, Rows.ROW_H)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * Rows.ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:HookScript("PreClick", function() Rows.PreClick(row) end)
    row:HookScript("PostClick", function(_, button) Rows.OnClick(row, button) end)
    row:SetScript("OnEnter", function() Rows.OnEnter(row) end)
    row:SetScript("OnLeave", Rows.OnLeave)
    regions(row)
    controls(row)
    secureChild(row)
    return row
end

--- Build the 14 rows into `list`, once. Out of combat only (Dock.Refresh is the one caller).
--- @param list table the list body frame
--- @return table[] the rows
function Rows.Build(list)
    if Rows.built then return Rows.rows end
    Rows.built = true
    local pool = NS.Pool.New()
    for i = 1, Rows.COUNT do
        Rows.rows[i] = NS.Pool.Acquire(pool, function() return newRow(list, i) end)
    end
    return Rows.rows
end

--- Re-assert the rows' levels over `base` (the list body's level): the controls at row +
--- ROW_CONTROLS, the secure child at row + ROW_SECURE (frame-layering-§3).
--- @param base number
function Rows.Relevel(base)
    for _, row in ipairs(Rows.rows) do
        row:SetFrameLevel(base)
        row.worn:SetFrameLevel(base + LEVEL.ROW_CONTROLS)
        row.em:SetFrameLevel(base + LEVEL.ROW_CONTROLS)
        row.menu:SetFrameLevel(base + LEVEL.ROW_CONTROLS)
        row.secure:SetFrameLevel(base + LEVEL.ROW_SECURE)
    end
end
