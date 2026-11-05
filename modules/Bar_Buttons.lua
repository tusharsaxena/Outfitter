local _, NS = ...
-- modules/Bar_Buttons.lua — the outfit bar's pooled buttons (design §7.7, INV §7.6; OutfitterBar.lua
-- :330-861 at 7ea3dc3). Extends NS.Bar (modules/Bar.lua) with OutfitIcon, NewButton and SetButton.
--
-- THE ICON is NS.OutfitIcon (modules/Outfits.lua), the one resolver the window's rows and the broker
-- draw too, its tint included (plan Task 3.5); Bar.OutfitIcon stays as its name on the bar.
--
-- A BUTTON is `bar.icons.size` square (Render sizes it): its icon (`btn.icon`, square-cropped), its
-- edge, its worn mark (`btn.worn`, in `of.bar.worn`) and accent edge (`btn.wornEdge`), and the
-- outfit record it stands for (`btn.outfit`). No Masque (INV §7.6 Decide: LibButtonFacade is dead and
-- nothing replaces it).
--
-- THE EDGE is the Icons tab's Border block (smoke round 2 design G6). With both its companions on
-- (Use the skin's border, Use the skin's color) and no class color, it is the skin's own HUD icon
-- edge: S.IconBorder{ fromSkin, hud } on `btn.skinEdge`, a child frame, so a skin switch repaints it
-- with no host call. Otherwise that frame hides and `btn.edge` (a BackdropTemplate child made on
-- first need, Drop Watcher's IconStyle shape) draws the style and thickness (the skin's icon family
-- while its companion is on, S.Resolve) in the class color, the skin's `icon.border` or the swatch.
-- Show border off draws neither.
--
-- THE WORN HIGHLIGHT is `bar.worn.style`: the corner mark, an accent edge in `of.bar.worn`, both, or
-- none. No glow: that would need LibCustomGlow, which this addon does not vendor (design non-goal).
--
--   Left click   wear, or remove a worn outfit that is not Complete (a Complete outfit is re-worn, as
--                the legacy bar did), with { hw = true }; a manual wear clears the Disabled flag
--   Right click  the outfit menu, built afresh on every open (quirk 21: the legacy kept the pooled
--                menu frame and checked `.released`; the library hides the menu itself). The bar
--                closes it whenever the bar hides: Bar.IsButton is how it knows the menu is its own
--   Hover        the outfit tooltip, `always` (the legacy pShowEmptyTooltips), and the bar's hover
--   Drop         Alt held: the dropped item's, spell's or macro's icon becomes the outfit's icon
--                (NS.Outfits.SetIcon, so an Equipment Manager outfit's goes to its set; the spell
--                through C_Spell, fixing the removed GetSpellTexture).
--                Without Alt, a dropped item becomes a new outfit named after it, which is worn.
--
-- A PLACEHOLDER (test mode's sample outfits, `placeholder = true`) does nothing on any click or drop,
-- and its tooltip says so (H17): no write path below runs for one.
--
-- CALLS (at call time, no nil guard; design §12): NS.Stack, NS.Outfits, NS.OutfitMenu.Open,
-- NS.OutfitTooltip.Show, NS.OutfitIcon, NS.Outfits.SetIcon, NS.ItemInfo.FromLink.

local Bar = NS.Bar

local L = NS.L
local Compat, Secrets = NS.Compat, NS.Secrets
local LAYERS = NS.Constants.LAYERS

local COMPLETE = "Complete"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local WORN_EDGE = 2                     -- the worn accent edge, in pixels
local ICONS = "bar.icons."

local function setting(path) return NS.GetSetting(path) end

-- Every button NewButton made, weak-keyed: a released button still owns a menu opened on it.
local mine = setmetatable({}, { __mode = "k" })

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
    -- The one icon writer, so an Equipment Manager outfit's drop reaches its set (Outfits.lua).
    NS.Outfits.SetIcon(btn.outfit.id, icon)
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

-- ── the edge and the worn highlight ───────────────────────────────────────────────────────────

--- A border setting as drawn: the skin's token `kind` while `fromSkin`, else the stored value (a
--- facade that cannot answer the token keeps the stored one).
local function follow(kind, key, fromSkin)
    local S = NS.Skin
    local stored = setting(ICONS .. key)
    local v = S.Resolve(kind, stored, fromSkin)
    if v == nil or v == S.FROM_SKIN then return stored end
    return v
end

--- The player's edge as drawn: its file, thickness and color, or nil for none.
local function ownEdge()
    local fromSkin = setting(ICONS .. "borderStyleFromSkin") ~= false
    local file = Bar.BorderFile(follow("icon.borderStyle", "borderStyle", fromSkin))
    if not file then return nil end
    local size = math.max(1, Secrets.UnsecretNumber(follow("icon.borderSize", "borderSize", fromSkin), 1))
    local r, g, b, a = Bar.EdgeColor(ICONS, "icon.border")
    return { file = file, size = size, color = { r, g, b, a } }
end

--- What every button draws this render, read once (Render hands it to SetButton).
--- @return table { skin = bool, edge = table|nil, worn = string, wornColor = { r, g, b, a } }
function Bar.IconStyle()
    local c = { worn = setting("bar.worn.style") or "both" }
    local r, g, b, a = NS.Skin.Color("of.bar.worn")
    c.wornColor = { r or 1, g or 0.82, b or 0, a or 1 }
    if setting(ICONS .. "borderShow") == false then return c end
    local followsSkin = setting(ICONS .. "borderStyleFromSkin") ~= false
        and setting(ICONS .. "borderColorFromSkin") ~= false and setting(ICONS .. "useClassColorBorder") ~= true
    if followsSkin then c.skin = true else c.edge = ownEdge() end
    return c
end

--- Button child `key`, a backdrop frame over the whole button, made on first use (relevel sets its level).
local function backdropFrame(btn, key)
    local f = btn[key]
    if f then return f end
    f = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    f:SetAllPoints(btn)
    btn[key] = f
    return f
end

--- Every child frame on its rung over the button's level, again on every fill: Render re-levels the
--- button after a pooled one made its children (frame-layering-§3, re-assert what moves).
local function relevel(btn)
    local base = Secrets.UnsecretNumber(btn:GetFrameLevel(), 0)
    btn.skinEdge:SetFrameLevel(base + LAYERS.LEVEL.BAR_EDGE)
    btn.overlay:SetFrameLevel(base + LAYERS.LEVEL.BAR_OVERLAY)
    if btn.edge then btn.edge:SetFrameLevel(base + LAYERS.LEVEL.BAR_EDGE) end
    if btn.wornEdge then btn.wornEdge:SetFrameLevel(base + LAYERS.LEVEL.BAR_WORN_EDGE) end
end

local function paintEdge(btn, style)
    btn.skinEdge:SetShown(style.skin == true)
    local e = style.edge
    if not e then
        if btn.edge then btn.edge:Hide() end
        return
    end
    local f = backdropFrame(btn, "edge")
    f:SetBackdrop({ edgeFile = e.file, edgeSize = e.size })
    f:SetBackdropBorderColor(e.color[1], e.color[2], e.color[3], e.color[4])
    f:Show()
end

local SHOWS_MARK = { mark = true, both = true }
local SHOWS_EDGE = { border = true, both = true }

local function paintWorn(btn, style, worn)
    btn.worn:SetShown(worn and SHOWS_MARK[style.worn] == true)
    local f = backdropFrame(btn, "wornEdge")
    f:SetBackdrop({ edgeFile = WHITE, edgeSize = WORN_EDGE })
    local c = style.wornColor
    f:SetBackdropBorderColor(c[1], c[2], c[3], c[4])
    f:SetShown(worn and SHOWS_EDGE[style.worn] == true)
end

-- ── build and fill ────────────────────────────────────────────────────────────────────────────

--- A new button on row frame `parent` (the pool's factory).
--- @param parent table
--- @return table
function Bar.NewButton(parent)
    local S = NS.Skin
    local btn = CreateFrame("Button", nil, parent)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    -- The worn mark on a mouse-off overlay over the edges, never a region under its own children.
    btn.overlay = CreateFrame("Frame", nil, btn)
    btn.overlay:SetAllPoints(btn)
    btn.overlay:EnableMouse(false)
    btn.worn = btn.overlay:CreateTexture(nil, "OVERLAY")
    btn.worn:SetSize(14, 14)
    btn.worn:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
    btn.worn:Hide()
    -- The art's own border trimmed by hand: S.SquareIcon would also hang a permanent edge in the
    -- window outline on the button, one Show border never reaches (smoke round 3 E5).
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.skinEdge = CreateFrame("Frame", nil, btn)
    btn.skinEdge:SetAllPoints(btn)
    S.IconBorder(btn.skinEdge, { fromSkin = true, hud = true, icon = btn.icon })
    S.Mark(btn.worn, { token = "of.bar.worn", art = NS.Icon("confirm") })
    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnReceiveDrag", onReceiveDrag)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", onLeave)
    mine[btn] = true
    return btn
end

--- Whether `frame` is one of the bar's buttons: the claim the bar hands NS.CloseMenuFrom, so its
--- hide takes down the outfit menu a right click opened here and no other.
--- @param frame table|nil
--- @return boolean
function Bar.IsButton(frame)
    return frame ~= nil and mine[frame] == true
end

--- Point `btn` at outfit `rec`: its icon, its edge, and its worn highlight (never on a placeholder).
--- @param btn table
--- @param rec table
--- @param style table|nil Bar.IconStyle()'s answer (nil reads it)
function Bar.SetButton(btn, rec, style)
    style = style or Bar.IconStyle()
    btn.outfit = rec
    local tex, r, g, b = Bar.OutfitIcon(rec)
    btn.icon:SetTexture(tex)
    -- Every time, white included: a pooled button keeps the last tint it drew.
    btn.icon:SetVertexColor(r, g, b)
    paintEdge(btn, style)
    paintWorn(btn, style, not rec.placeholder and NS.Stack.IsWorn(rec.id) == true)
    relevel(btn)
end
