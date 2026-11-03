local _, NS = ...
-- modules/Tooltips.lua — NS.Tooltips: the "Used by outfits" line on item tooltips (design §7.10, INV §3.8).
--
-- ONE TooltipDataProcessor post-call on item tooltips, registered once on the first stand-up (Resume,
-- which the login's OnEnable runs; H15). A post-call cannot be removed, so a stand-down leaves it
-- installed and OnItem reads the gates first: the latch, `tooltip.usedBy`, GameTooltip or a stock
-- shopping tooltip (ShoppingTooltip1/2, the worn items beside a compare: the legacy compare path
-- decorated them, Outfitter.lua:7885-7893), the player's own inventory only (another unit's gear, or
-- an inventory tooltip whose unit cannot be read, never gets the line; O41), and a plain link.
--
-- THE LINE is EQUIPMENT_SETS formatted with the outfits that use the item, each name colored by its
-- status (disabled, missing, banked, normal); banked is `of.outfit.banked`, blue, where the legacy
-- line drew it red. It is cached per plain link and the cache is wiped on every outfit-record message
-- and INVENTORY_CHANGED, and by Refresh (the `tooltip.usedBy` row's reaction).
--
-- REPLACING THE CLIENT'S LINE (O34). The client draws its own "Equipment Sets:" line for an item in a
-- Blizzard set; ours replaces it through SetText on the matched left fontstring, found with a search
-- pattern built once from EQUIPMENT_SETS. A line whose text is secret is skipped, never searched.
-- With no match the line is appended. The search pattern conversion is the legacy addon's own
-- (Outfitter.lua:5808-5825): the client has no such function.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.UsingItem/Get/Status.

local Tooltips = {}
NS.Tooltips = Tooltips

local Compat, Secrets = NS.Compat, NS.Secrets
local L = NS.L

local MAX_LINES = 100        -- a ceiling on one tooltip's walk, far beyond any item tooltip
local STATUS_TOKEN = {
    disabled = "of.outfit.disabled", missing = "of.outfit.missing", banked = "of.outfit.banked",
    normal = "text.highlight",
}
-- NORMAL_FONT_COLOR, the color the legacy appended line was drawn in (Outfitter.lua:7246).
local LINE_R, LINE_G, LINE_B = 1, 0.82, 0

local installed = false
local cache = {}             -- [plain link] = the line, or false for "no outfit uses it"
local pattern                -- the EQUIPMENT_SETS search pattern, built once
local bus                    -- this module's bus receiver

-- ── the line ──────────────────────────────────────────────────────────────────────────────────

-- The client's format, or the enUS one on a client that has none.
local function setsFormat()
    local fmt = Secrets.PlainString(EQUIPMENT_SETS)
    return fmt or L["Equipment Sets: %s"]
end

local DEFORMAT = { s = "(.-)", d = "(-?[%d]+)", f = "(-?[%d%.]+)", g = "(-?[%d%.]+)", ["%"] = "%%" }

--- A format string as a Lua search pattern: the legacy ConvertFormatStringToSearchPattern.
--- @param fmt string
--- @return string
function Tooltips.SearchPattern(fmt)
    -- The magic characters a GlobalString's text may hold, all but `-`, which a conversion's flags use.
    local escaped = fmt:gsub("[%[%]%.%(%)%+%*%?%^%$]", function(c) return "%" .. c end)
    return (escaped:gsub("%%[%-%d%.]-([sdgf%%])", DEFORMAT))
end

local function setsPattern()
    pattern = pattern or Tooltips.SearchPattern(setsFormat())
    return pattern
end

-- One outfit's name in its status color.
local function coloredName(id)
    local O = NS.Outfits
    local rec = O.Get(id)
    if not rec then return nil end
    local esc = NS.SkinEscape(STATUS_TOKEN[O.Status(id)] or STATUS_TOKEN.normal) or ""
    return esc .. tostring(rec.name) .. "|r"
end

local function buildLine(link)
    local names = {}
    for _, id in ipairs(NS.Outfits.UsingItem(link)) do
        names[#names + 1] = coloredName(id)
    end
    if #names == 0 then return false end
    return setsFormat():format(table.concat(names, ", "))
end

--- The "Equipment Sets: ..." line for an item link, or nil when no outfit uses it (or the link is
--- secret). Cached per link until the next outfit or inventory change.
--- @param link any
--- @return string|nil
function Tooltips.LineFor(link)
    local plain = Secrets.PlainString(link)
    if not plain then return nil end
    local line = cache[plain]
    if line == nil then
        line = buildLine(plain)
        cache[plain] = line
    end
    return line or nil
end

--- Wipe the line cache (the `tooltip.usedBy` row's reaction, design §4.2).
function Tooltips.Refresh()
    cache = {}
end

-- ── drawing ───────────────────────────────────────────────────────────────────────────────────

--- A tooltip's fontstring `side` ("Left" or "Right") on line `i`: by the tooltip's global name, as the
--- client names them, or the field of that name.
--- @return table|nil
function Tooltips.FontString(tooltip, side, i)
    local key = "Text" .. side .. i
    local name = tooltip:GetName()
    local fs = type(name) == "string" and _G[name .. key] or nil
    return fs or rawget(tooltip, key)
end

-- The left fontstring whose plain text matches the Equipment Sets pattern, or nil.
local function setsLine(tooltip)
    local find, pat = string.find, setsPattern()
    local n = math.min(Secrets.UnsecretNumber(tooltip:NumLines(), 0), MAX_LINES)
    for i = 1, n do
        local fs = Tooltips.FontString(tooltip, "Left", i)
        local text = fs and Secrets.PlainString(fs:GetText())
        if text then
            local ok, hit = pcall(find, text, pat)
            if ok and hit then return fs end
        end
    end
    return nil
end

--- Put an item's line on `tooltip`: over the client's Equipment Sets line, or appended. True when a
--- line was drawn. The compare tooltips call this for their own items.
--- @return boolean
function Tooltips.Decorate(tooltip, link)
    local line = Tooltips.LineFor(link)
    if not line then return false end
    local fs = setsLine(tooltip)
    if fs then
        fs:SetText(line)
    else
        tooltip:AddLine(line, LINE_R, LINE_G, LINE_B, true)
        tooltip:Show()
    end
    return true
end

-- The plain link the tooltip shows, or nil.
local function displayedLink(tooltip)
    local util = TooltipUtil
    local get = util and util.GetDisplayedItem
    local ok, _, link
    if type(get) == "function" then
        ok, _, link = pcall(get, tooltip)
    else
        ok, _, link = pcall(tooltip.GetItem, tooltip)
    end
    if not ok then return nil end
    return Secrets.PlainString(link)
end

-- Whether the tooltip is the one this line belongs on. Our own compare tooltips are not: they
-- decorate themselves after their title line goes in.
local function wanted(tooltip)
    if NS.IsStoodDown() or NS.GetSetting("tooltip.usedBy") == false then return false end
    if tooltip == nil or (tooltip ~= GameTooltip and tooltip ~= ShoppingTooltip1 and tooltip ~= ShoppingTooltip2) then
        return false
    end
    local unit = Compat.TooltipInventoryUnit(tooltip)
    return unit == nil or unit == "player"
end

--- The item post-call: the gates, then the line (perf bucket `tooltipUsedBy`).
function Tooltips.OnItem(tooltip)
    if not wanted(tooltip) then return end
    local link = displayedLink(tooltip)
    if not link then return end
    local Perf = NS.Perf
    local t0 = Perf.on and debugprofilestop()
    Tooltips.Decorate(tooltip, link)
    if t0 then Perf.Note("tooltipUsedBy", debugprofilestop() - t0) end
end

-- ── the lifecycle ─────────────────────────────────────────────────────────────────────────────

local WIPE_ON = { "OUTFIT_ADDED", "OUTFIT_DELETED", "OUTFIT_EDITED", "OUTFIT_RENAMED", "INVENTORY_CHANGED" }

--- Install the post-call and the cache's bus receiver: once per session.
function Tooltips.Install()
    if installed then return end
    installed = true
    local proc = TooltipDataProcessor
    local kinds = Enum and Enum.TooltipDataType
    if proc and proc.AddTooltipPostCall and kinds and kinds.Item then
        proc.AddTooltipPostCall(kinds.Item, Tooltips.OnItem)
    end
    bus = NS.NewBusTarget()
    if not bus then return end
    for _, key in ipairs(WIPE_ON) do
        bus:RegisterMessage(NS.MSG[key], Tooltips.Refresh)
    end
end

--- The lifecycle's stand-down (design §5.12): the post-call stays and reads the latch; the bus record
--- drops the receiver's registrations; the cache goes.
function Tooltips.Suspend()
    Tooltips.Refresh()
end

--- The stand-up: installs the post-call the first time, and starts from an empty cache.
function Tooltips.Resume()
    Tooltips.Install()
    Tooltips.Refresh()
end
