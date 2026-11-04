local _, NS = ...
-- modules/Bar_Buttons.lua — the outfit bar's pooled buttons (design §7.7, INV §7.6; OutfitterBar.lua
-- :330-861 at 7ea3dc3). Extends NS.Bar (modules/Bar.lua) with OutfitIcon, NewButton and SetButton.
--
-- THE ICON is NS.OutfitIcon (modules/Outfits.lua), the one resolver the window's rows and the broker
-- draw too, its tint included (plan Task 3.5); Bar.OutfitIcon stays as its name on the bar.
--
-- A BUTTON is 32 x 32: its icon (`btn.icon`, square-cropped and edged as a HUD icon), its worn mark
-- (`btn.worn`, in `of.bar.worn`) and the outfit record it stands for (`btn.outfit`). No Masque (INV
-- §7.6 Decide: LibButtonFacade is dead and nothing replaces it).
--
--   Left click   wear, or remove a worn outfit that is not Complete (a Complete outfit is re-worn, as
--                the legacy bar did), with { hw = true }; a manual wear clears the Disabled flag
--   Right click  the outfit menu, built afresh on every open (quirk 21: the legacy kept the pooled
--                menu frame and checked `.released`; the library hides the menu itself)
--   Hover        the outfit tooltip, `always` (the legacy pShowEmptyTooltips), and the bar's hover
--   Drop         Alt held: the dropped item's, spell's or macro's icon becomes the outfit's icon
--                (`outfit.icon`; the spell through C_Spell, fixing the removed GetSpellTexture).
--                Without Alt, a dropped item becomes a new outfit named after it, which is worn.
--
-- A PLACEHOLDER (test mode's sample outfits, `placeholder = true`) does nothing on any click or drop,
-- and its tooltip says so (H17): no write path below runs for one.
--
-- CALLS (at call time, no nil guard; design §12): NS.Stack, NS.Outfits, NS.OutfitMenu.Open,
-- NS.OutfitTooltip.Show, NS.OutfitIcon, NS.SetByPath, NS.ItemInfo.FromLink.

local Bar = NS.Bar

local L = NS.L
local Compat, Secrets = NS.Compat, NS.Secrets

local COMPLETE = "Complete"

-- The legacy plain icon and the Birthday Suit's, now the resolver's (modules/Outfits.lua).
Bar.PLAIN_ICON, Bar.NAKED_ICON = NS.Outfits.PLAIN_ICON, NS.Outfits.NAKED_ICON

local function plainIcon(v)
    local n = Secrets.PlainNumber(v)
    if n and n > 0 then return n end
    return nil
end

--- An outfit's icon: NS.OutfitIcon's answer, texture then r, g, b.
--- @param rec table
--- @return number|string texture, number r, number g, number b
function Bar.OutfitIcon(rec)
    return NS.OutfitIcon(rec)
end

-- ── the cursor ────────────────────────────────────────────────────────────────────────────────

-- The icon of what the cursor holds, by kind; the spell's id is GetCursorInfo's third value after
-- the kind (index, book, spellID).
local CURSOR_ICON = {
    item  = function(itemID) return Compat.ItemIcon(itemID) end,
    spell = function(_, _, spellID)
        local fn = C_Spell and C_Spell.GetSpellTexture
        return fn and spellID and fn(spellID)
    end,
    macro = function(index)
        if type(GetMacroInfo) ~= "function" or not index then return nil end
        local _, icon = GetMacroInfo(index)
        return icon
    end,
}

--- Alt held: write the cursor's icon as the outfit's. Answers whether it wrote one.
local function dropIcon(btn, kind, a, b, c)
    local read = CURSOR_ICON[kind]
    local icon = read and plainIcon(read(a, b, c))
    if not icon then return false end
    NS.SetByPath("outfit.icon", icon, btn.outfit.id)
    Compat.ClearCursor()
    return true
end

--- A dropped item: a new outfit named after it, worn. The item goes back to its bag first, so the
--- wear moves it from there. An item that cannot make one stays on the cursor, with the legacy's
--- reason printed (OutfitterBar.lua:759-768).
local function dropItem(link)
    local plain = Secrets.PlainString(link)
    local info = plain and NS.ItemInfo.FromLink(plain)
    if not info then
        NS.Print(L["Couldn't get information about the item being dropped"])
        return false
    end
    local id = NS.Outfits.CreateFromItem(plain)
    if not id then
        NS.Print(L["Couldn't make an outfit from %s because it isn't equippable"]:format(
            Secrets.PlainString(info.name) or plain))
        return false
    end
    Compat.ClearCursor()
    NS.Stack.Wear(id, { hw = true })
    return true
end

--- Take what the cursor holds. Answers whether the cursor held anything (a click is then a drop).
--- @param btn table
--- @return boolean
function Bar.Drop(btn)
    local kind, a, b, c = GetCursorInfo()
    if not kind then return false end
    if btn.outfit.placeholder then return true end
    if IsAltKeyDown() then
        dropIcon(btn, kind, a, b, c)
    elseif kind == "item" then
        dropItem(b)
    end
    return true
end

-- ── the scripts ───────────────────────────────────────────────────────────────────────────────

local function leftClick(btn)
    local rec = btn.outfit
    local opts = { hw = true, clearDisabled = true }
    if rec.category == COMPLETE or not NS.Stack.IsWorn(rec.id) then
        NS.Stack.Wear(rec.id, opts)
    else
        NS.Stack.Remove(rec.id, opts)
    end
end

local function onClick(btn, mouse)
    local rec = btn.outfit
    if not rec or rec.placeholder then return end
    if mouse == "RightButton" then return NS.OutfitMenu.Open(btn, rec.id) end
    if Bar.Drop(btn) then return end
    leftClick(btn)
end

local function onReceiveDrag(btn)
    if btn.outfit then Bar.Drop(btn) end
end

local function onEnter(btn)
    Bar.HoverIn()
    local rec = btn.outfit
    if not rec then return end
    if rec.placeholder then
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetText(tostring(rec.name))
        GameTooltip:AddLine(L["Sample outfit (test mode). Nothing is equipped."], nil, nil, nil, true)
        GameTooltip:Show()
        return
    end
    if not NS.OutfitTooltip.Show(rec.id, btn, "ANCHOR_RIGHT", true) then GameTooltip:Hide() end
end

local function onLeave()
    GameTooltip:Hide()
    Bar.HoverOut()
end

-- ── build and fill ────────────────────────────────────────────────────────────────────────────

--- A new button on row frame `parent` (the pool's factory).
--- @param parent table
--- @return table
function Bar.NewButton(parent)
    local S = NS.Skin
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(Bar.BUTTON_SIZE, Bar.BUTTON_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.worn = btn:CreateTexture(nil, "OVERLAY")
    btn.worn:SetSize(14, 14)
    btn.worn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    btn.worn:Hide()
    S.SquareIcon(btn, { crop = true })
    S.IconBorder(btn, { fromSkin = true, hud = true })
    S.Mark(btn.worn, { token = "of.bar.worn", art = NS.Icon("confirm") })
    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnReceiveDrag", onReceiveDrag)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", onLeave)
    return btn
end

--- Point `btn` at outfit `rec`: its icon, and its worn mark (never on a placeholder).
--- @param btn table
--- @param rec table
function Bar.SetButton(btn, rec)
    btn.outfit = rec
    local tex, r, g, b = Bar.OutfitIcon(rec)
    btn.icon:SetTexture(tex)
    -- Every time, white included: a pooled button keeps the last tint it drew.
    btn.icon:SetVertexColor(r, g, b)
    btn.worn:SetShown(not rec.placeholder and NS.Stack.IsWorn(rec.id))
end
