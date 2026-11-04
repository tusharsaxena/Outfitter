local _, NS = ...
-- modules/Tooltips_Compare.lua — NS.Compare: up to five comparison tooltips with the items your
-- outfits use in the hovered item's slot (design §7.10, INV §3.8 "Extended compare").
--
-- A POST-HOOK on the client's GameTooltip_ShowCompareItem (Compat.HookCompare), installed once on the
-- first stand-up, whose body reads the gates first: the latch, `tooltip.compare`, the client's own
-- TooltipUtil.ShouldDoItemComparison() and the COMPAREITEMS modifier (either one off, ours hide), a
-- plain link and armor only.
--
-- WHAT SHOWS. The items outfits without `ignoreComparisons` put in the hovered item's slot (both
-- fingers, both trinkets), quality 2 and up, highest item level first; an item already on GameTooltip,
-- the stock shopping tooltips or one of ours is skipped. Each is drawn on a lazy
-- OutfitterRebornCompareTooltip<N> (ShoppingTooltipTemplate, painted by S.Tooltip at creation, tier
-- CURSOR), whose line 1 is "<outfit> | Outfitter" in `text.muted`, followed by the item's own lines
-- and its "Used by outfits" line.
--
-- PLACEMENT. Beside the outermost stock shopping tooltip that shows (ShoppingTooltip2, else 1, else
-- GameTooltip itself), towards the side of the screen with more room; each next one beside the last.
-- A tooltip that shows hidden information has secret geometry: then it is left to right.
--
-- HIDING. GameTooltip's OnHide (a HookScript that touches only our frames), the modifier released,
-- Refresh (the `tooltip.compare` row) and the stand-down hide all five. The release is caught by an
-- OnUpdate HookScript on the first compare tooltip (Compare.OnTick; it is shown whenever any is, and
-- runs only while shown), as the legacy per-tooltip OnUpdate did (Outfitter.lua:8057-8064): the
-- client does not call GameTooltip_ShowCompareItem when the modifier goes up. The LibTipHooker
-- re-dispatch the legacy addon made is gone with the library (H15).
--
-- CLIENT READS beyond this file's luacheck stanza go through `_G` by name, at call time:
-- IsModifiedClick and GetScreenWidth.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Categories/Ids/Get/Items,
-- NS.Tooltips.Decorate/FontString.

local Compare = {}
NS.Compare = Compare

local Compat, Secrets = NS.Compat, NS.Secrets
local L = NS.L

local MAX = 5
local MIN_QUALITY = 2
local ARMOR_FALLBACK = 4     -- Enum.ItemClass.Armor
local PAIRS = { Finger0Slot = "Finger1Slot", Trinket0Slot = "Trinket1Slot" }

local installed = false
local frames = {}            -- [n] = our compare tooltip, built on first use

-- ── the gates ─────────────────────────────────────────────────────────────────────────────────

local function armorClass()
    local classes = Enum and Enum.ItemClass
    return classes and classes.Armor or ARMOR_FALLBACK
end

-- The client's wish for a comparison; a client without the call always compares.
local function clientWantsCompare()
    local util = TooltipUtil
    local fn = util and util.ShouldDoItemComparison
    if type(fn) ~= "function" then return true end
    local ok, want = pcall(fn)
    return ok and Secrets.PlainTruth(want) == true
end

local function modifierHeld()
    local fn = IsModifiedClick
    if type(fn) ~= "function" then return true end
    return Secrets.PlainTruth(fn("COMPAREITEMS")) == true
end

-- ── the candidates ────────────────────────────────────────────────────────────────────────────

-- The outfit slots the item is compared in: its own, and its pair's partner.
local function slotsOf(info)
    local partner = PAIRS[info.slot]
    if partner then return { info.slot, partner } end
    return { info.slot }
end

local function candidate(rec, item)
    if not item or item.id == 0 or (Secrets.PlainNumber(item.quality) or 0) < MIN_QUALITY then return nil end
    local link = Secrets.PlainString(item.link)
    if not link then return nil end
    return { outfit = tostring(rec.name), link = link, level = Secrets.PlainNumber(item.level) or 0 }
end

--- The items the outfits offer for `info`'s slot, highest level first (store order breaks a tie).
--- @param info table  an item info with a slot
--- @return table[]  { outfit, link, level }
function Compare.Candidates(info)
    local O, out, slots = NS.Outfits, {}, slotsOf(info)
    for _, category in ipairs(O.Categories()) do
        for _, id in ipairs(O.Ids(category)) do
            local rec = O.Get(id)
            if rec and not rec.ignoreComparisons then
                local items = O.Items(rec)
                for _, slot in ipairs(slots) do
                    local c = candidate(rec, items[slot])
                    if c then
                        c.order = #out + 1
                        out[#out + 1] = c
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.order < b.order
    end)
    return out
end

-- The identity a duplicate is judged on (the legacy ItemsAreEquivalent: code, subcode, unique id).
local function identity(link)
    local f = NS.ItemInfo.ParseLink(link)
    if not f then return nil end
    return f.id .. ":" .. f.suffix .. ":" .. f.uid
end

-- The identities on the tooltips already showing: GameTooltip and the stock shopping pair.
local function shownIdentities()
    local seen = {}
    for _, tip in ipairs({ GameTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tip and (tip == GameTooltip or tip:IsShown()) then
            local ok, _, link = pcall(tip.GetItem, tip)
            local key = ok and identity(link)
            if key then seen[key] = true end
        end
    end
    return seen
end

-- ── placement and drawing ─────────────────────────────────────────────────────────────────────

--- Where the first compare tooltip goes: the anchor, and whether it is to the anchor's right.
--- @return table anchor
--- @return boolean toRight
function Compare.Placement()
    local anchor = GameTooltip
    if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then
        anchor = ShoppingTooltip2
    elseif ShoppingTooltip1 and ShoppingTooltip1:IsShown() then
        anchor = ShoppingTooltip1
    end
    local screen = GetScreenWidth
    local left = Secrets.PlainNumber(GameTooltip:GetLeft())
    local right = Secrets.PlainNumber(GameTooltip:GetRight())
    local width = type(screen) == "function" and Secrets.PlainNumber(screen()) or nil
    if not (left and right and width) then return anchor, true end
    return anchor, left < width - right
end

local function frameAt(n)
    local tip = frames[n]
    if tip then return tip end
    tip = CreateFrame("GameTooltip", "OutfitterRebornCompareTooltip" .. n, UIParent, "ShoppingTooltipTemplate")
    tip:SetFrameStrata(NS.Constants.LAYERS.STRATA.CURSOR)
    if n == 1 then tip:HookScript("OnUpdate", function() Compare.OnTick() end) end
    local S = NS.Skin
    if S and S.Tooltip then S.Tooltip(tip) end
    tip:Hide()
    frames[n] = tip
    return tip
end

-- Copy one line's text and color down to the next line.
local function shiftLine(tip, side, i)
    local from, to = NS.Tooltips.FontString(tip, side, i), NS.Tooltips.FontString(tip, side, i + 1)
    if not (from and to) then return end
    to:SetText(from:GetText())
    to:SetTextColor(from:GetTextColor())
end

-- Push every line down one and write "<outfit> | Outfitter" on line 1.
local function writeTitle(tip, outfit)
    local n = math.min(Secrets.UnsecretNumber(tip:NumLines(), 0), 100)
    tip:AddLine(" ")
    for i = n, 1, -1 do
        shiftLine(tip, "Left", i)
        shiftLine(tip, "Right", i)
    end
    local r, g, b = NS.SkinColor("text.muted")
    local left, right = NS.Tooltips.FontString(tip, "Left", 1), NS.Tooltips.FontString(tip, "Right", 1)
    if left then
        left:SetText(outfit)
        left:SetTextColor(r, g, b)
    end
    if right then
        right:SetText(L["Outfitter"])
        right:SetTextColor(r, g, b)
        right:Show()
    end
end

local function draw(n, c, anchor, toRight)
    local tip = frameAt(n)
    tip:SetOwner(anchor, "ANCHOR_NONE")
    tip:ClearAllPoints()
    if toRight then
        tip:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
    else
        tip:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, 0)
    end
    tip:SetHyperlink(c.link)
    writeTitle(tip, c.outfit)
    NS.Tooltips.Decorate(tip, c.link)
    tip:Show()
    return tip
end

--- Hide every compare tooltip (ours only).
function Compare.HideAll()
    for _, tip in ipairs(frames) do
        tip:ClearAllPoints()
        tip:Hide()
    end
end

--- Show the compare tooltips for GameTooltip's item. Answers how many were drawn.
--- @return number
function Compare.Show()
    Compare.HideAll()
    local ok, _, link = pcall(GameTooltip.GetItem, GameTooltip)
    link = ok and Secrets.PlainString(link)
    local info = link and NS.ItemInfo.FromLink(link)
    if not (info and info.slot and info.classID == armorClass()) then return 0 end
    local seen, n = shownIdentities(), 0
    local anchor, toRight = Compare.Placement()
    for _, c in ipairs(Compare.Candidates(info)) do
        if n >= MAX then break end
        local key = identity(c.link)
        if key and not seen[key] then
            seen[key] = true
            n = n + 1
            anchor = draw(n, c, anchor, toRight)
        end
    end
    return n
end

-- Whether a comparison is wanted now: the client's wish and the COMPAREITEMS modifier both.
local function compareWanted()
    return clientWantsCompare() and modifierHeld()
end

--- The GameTooltip_ShowCompareItem post-hook body: the gates, then Show (or HideAll).
function Compare.OnShowCompare(tooltip)
    if NS.IsStoodDown() or NS.GetSetting("tooltip.compare") == false then return end
    if tooltip ~= nil and tooltip ~= GameTooltip then return end
    if not compareWanted() then return Compare.HideAll() end
    Compare.Show()
end

--- The first compare tooltip's OnUpdate: a released modifier (or a client that stops wanting the
--- comparison) hides ours while the item stays hovered.
function Compare.OnTick()
    if not compareWanted() then Compare.HideAll() end
end

--- Hide them all (the `tooltip.compare` row's reaction, design §4.2).
function Compare.Refresh()
    Compare.HideAll()
end

-- ── the lifecycle ─────────────────────────────────────────────────────────────────────────────

--- Install the compare hook and GameTooltip's OnHide: once per session.
function Compare.Install()
    if installed then return end
    installed = true
    Compat.HookCompare(Compare.OnShowCompare)
    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnHide", function() Compare.HideAll() end)
    end
end

--- The lifecycle's stand-down (design §5.12): the hooks stay and read the latch; ours hide.
function Compare.Suspend()
    Compare.HideAll()
end

--- The stand-up: installs the hooks the first time.
function Compare.Resume()
    Compare.Install()
end
