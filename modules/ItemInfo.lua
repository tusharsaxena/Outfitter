local _, NS = ...
-- modules/ItemInfo.lua — NS.ItemInfo: link parse, item identity and comparison (design §5.3).
--
-- THE CHOKE POINT (INV §12). Every item link the engine reads passes through ParseLink, which asks
-- NS.Secrets.PlainString first: a secret link answers nil, the same answer as an empty slot (Q12),
-- and is never matched or stored. The id and the bonus list come from the NS.Item lease
-- (core/ItemSetup.lua); the rest of the itemString is a table-driven positional walk.
--
-- TWO SHAPES OF ITEM leave this file:
--   info    a live cache object (FromLink / FromBag / FromSlot): the parsed fields, the client's
--           item info, the slot it goes in, and its location. Bind, UniqueKeys and Usable are lazy
--           and cached on it. Never saved.
--   record  the ItemRecord of design §3.3 (Snapshot): only the canonical keys, safe to store.
--
-- The client is read only through NS.Compat; the GlobalStrings the tooltip fallbacks compare
-- against are read by name at call time, so a client that changes one is seen.

local II = {}
NS.ItemInfo = II

local Compat, Secrets = NS.Compat, NS.Secrets
local L = NS.L

-- ── the link ──────────────────────────────────────────────────────────────────────────────────

-- itemString positions (1 = the id). 9 (LinkLevel) and 10 (SpecializationID) are deliberately not
-- captured (Q9): they describe whoever made the link, not the item.
local FIELD_POS = {
    { "enchant", 2 }, { "gem1", 3 }, { "gem2", 4 }, { "gem3", 5 }, { "gem4", 6 },
    { "suffix", 7 }, { "uid", 8 }, { "upType", 11 }, { "diff", 12 },
}
local BONUS_COUNT_POS = 13   -- the declared bonus count n; the ids are 14..13+n, the modifier count 14+n

-- A positional field as a signed number: an empty or missing field reads 0 (B11).
local function num(s)
    if s == nil then return 0 end
    return tonumber(s:match("^(-?%d*)")) or 0
end

-- The itemString's fields, empty ones kept: the string is positional.
local function splitFields(plain)
    local body = plain:match("item:([%-%d:]*)")
    local fields = {}
    if not body then return fields end
    for v in (body .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = v end
    return fields
end

-- The modifier pairs after the bonus list as "type=value", ":"-joined (B12). A pair the link
-- declares but does not carry ends the list.
local function modifiers(fields, n)
    local countPos = BONUS_COUNT_POS + n + 1
    local out = {}
    for j = 1, num(fields[countPos]) do
        local t = fields[countPos + 2 * j - 1]
        if t == nil or t == "" then break end
        out[#out + 1] = num(t) .. "=" .. num(fields[countPos + 2 * j])
    end
    return table.concat(out, ":")
end

--- Parse an item link (or a bare itemString) into its canonical fields, and the name it shows.
--- nil for nil, a non-string, a secret, or a link that carries no item.
--- @param link any
--- @return table|nil fields  { id, enchant, gems, suffix, uid, upType, diff, bonus, mods }
--- @return string|nil name
function II.ParseLink(link)
    local plain = Secrets.PlainString(link)
    if not plain then return nil end
    local id = NS.Item.ItemIDFromLink(plain)
    if not id then return nil end
    local raw = splitFields(plain)
    local f = { id = id }
    for _, pos in ipairs(FIELD_POS) do f[pos[1]] = num(raw[pos[2]]) end
    f.gems = ("%d:%d:%d:%d"):format(f.gem1, f.gem2, f.gem3, f.gem4)
    f.gem1, f.gem2, f.gem3, f.gem4 = nil, nil, nil, nil
    f.bonus = table.concat(NS.Item.BonusIDsFromLink(plain) or {}, ":")
    f.mods = modifiers(raw, num(raw[BONUS_COUNT_POS]))
    return f, plain:match("|h%[(.-)%]|h")
end

-- ── item infos ────────────────────────────────────────────────────────────────────────────────

-- The client's item info onto `info`, then the corrections, then the slot the type goes in.
local function fill(info, link)
    local name, quality, level, minLevel, bindType = Compat.ItemInfo(link)
    info.name = info.name or name
    info.quality, info.level, info.minLevel, info.bindType = quality, level, minLevel, bindType
    local _, invType, _, classID, subclassID = Compat.ItemInfoInstant(link)
    info.invType, info.classID, info.subclassID = invType, classID, subclassID
    local data = NS.ItemData
    local fix = data.CORRECTIONS[info.id]
    if fix then
        for k, v in pairs(fix) do info[k] = v end
    end
    local slot = info.invType and data.INVTYPE_TO_SLOT[info.invType]
    if slot then info.slot, info.meta = slot.slot, slot.meta end
end

-- The sorted selected azerite powers at `loc`, ":"-joined; "" off azerite gear or with no location.
local function azeriteOf(loc)
    local powers = loc and Compat.AzeritePowers(loc)
    if not powers then return "" end
    return table.concat(powers, ":")
end

local function build(link, loc)
    local fields, name = II.ParseLink(link)
    if not fields then return nil end
    fields.link, fields.name, fields.loc = link, name, loc
    fill(fields, link)
    fields.bagType = Compat.ItemFamily(fields.id)
    fields.azerite = azeriteOf(loc)
    return fields
end

--- An item info from a link alone (no location: no azerite powers, binding read off the link).
--- @param link any
--- @return table|nil
function II.FromLink(link)
    return build(link, nil)
end

--- The item in a container slot, or nil (empty, or secret).
--- @param bag number
--- @param slot number
--- @return table|nil
function II.FromBag(bag, slot)
    return build(Compat.ContainerItemLink(bag, slot), { bag = bag, slot = slot })
end

--- The item worn in `slotName` ("HeadSlot"), or nil (empty, unknown slot, or secret).
--- @param slotName string
--- @return table|nil
function II.FromSlot(slotName)
    local slotID = Compat.InventorySlotID(slotName)
    if not slotID then return nil end
    return build(Compat.InventoryItemLink(slotID), { slotID = slotID, slotName = slotName })
end

-- ── lazy reads ────────────────────────────────────────────────────────────────────────────────

-- A GlobalString by name, read at call time.
local function globalString(name)
    return _G[name]
end

-- The tooltip lines of an info: by location when it has one, else by its link.
local function tooltipLines(info)
    return Compat.TooltipLines(info.loc or info.link)
end

-- The tooltip's binding line, for a client that cannot answer by location.
local TOOLTIP_BIND = {
    { "ITEM_BIND_ON_EQUIP", "boe" },
    { "ITEM_ACCOUNTBOUND_UNTIL_EQUIP", "warbound" },
    { "ITEM_SOULBOUND", "bound" },
}

-- The binding the tooltip shows, and whether that answer is settled: a tooltip with no lines at all
-- (its data not there yet) answers "none" unsettled, so it is asked again next time.
local function bindFromTooltip(info)
    local lines = tooltipLines(info)
    for _, line in ipairs(lines) do
        for _, row in ipairs(TOOLTIP_BIND) do
            local s = globalString(row[1])
            if s and line.text == s then return row[2], true end
        end
    end
    return "none", #lines > 0
end

-- The binding and whether it is settled. An unknown bindType (nil: the item not cached yet, common
-- for bag items right after login) is no "not BoE": the tooltip decides, as the legacy GetBoE did.
local function readBind(info)
    local bound = info.loc and Compat.IsBound(info.loc)
    if bound == true then return "bound", true end
    if info.loc and Compat.IsWarboundUntilEquip(info.loc) == true then return "warbound", true end
    if bound == nil or info.bindType == nil then return bindFromTooltip(info) end
    if info.bindType == 2 then return "boe", true end
    return "none", true
end

--- How the item binds: "bound", "boe" (binds when equipped), "warbound" (until equipped) or "none".
--- Lazy, and cached on the info once settled (an answer read off a tooltip with no data is not).
--- @param info table
--- @return string
function II.Bind(info)
    if info.bind ~= nil then return info.bind end
    local bind, settled = readBind(info)
    if settled then info.bind = bind end
    return bind
end

-- The client format "Unique-Equipped: %s (%d)" as a pattern capturing the category name.
local function limitPattern()
    local fmt = globalString("ITEM_LIMIT_CATEGORY_MULTIPLE")
    if type(fmt) ~= "string" then return nil end
    local escaped = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
    escaped = escaped:gsub("%%s", "(.+)"):gsub("%%d", "%%d+")
    return "^" .. escaped .. "$"
end

local function uniqueFromTooltip(info)
    local pattern, solo = limitPattern(), globalString("ITEM_UNIQUE_EQUIPPABLE")
    local keys
    for _, line in ipairs(tooltipLines(info)) do
        local name = pattern and line.text:match(pattern)
        if name then
            keys = keys or {}
            keys["n" .. name] = true
        elseif solo and line.text == solo then
            keys = keys or {}
            keys["i" .. info.id] = true
        end
    end
    return keys
end

local function readUnique(info)
    local u = Compat.ItemUniqueness(info.id)
    if u == nil then return uniqueFromTooltip(info) end
    if not u.unique then return nil end
    if u.categoryID then return { ["c" .. u.categoryID] = true } end
    return { ["i" .. info.id] = true }
end

--- The unique-equip keys the item counts against (`"c<categoryID>"`, `"i<itemID>"` for an item that
--- is unique itself, `"n<name>"` from the tooltip fallback), or nil. Lazy, and cached on the info.
--- @param info table
--- @return table|nil
function II.UniqueKeys(info)
    if info.uniqueKeys == nil then info.uniqueKeys = readUnique(info) or false end
    return info.uniqueKeys or nil
end

-- RGB (0..1) to hue in degrees, saturation and value.
local function hsv(r, g, b)
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local d = max - min
    if max == 0 then return 0, 0, 0 end
    local h = 0
    if d > 0 then
        if max == r then h = ((g - b) / d) % 6
        elseif max == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
    end
    return h * 60, d / max, max
end

-- A red line (B14): the legacy test, s > 0.2, v > 0.2 and a hue under 50 or over 310.
local function isRed(line)
    if not (line.r and line.g and line.b) then return false end
    local h, s, v = hsv(line.r, line.g, line.b)
    return s > 0.2 and v > 0.2 and (h < 50 or h > 310)
end

-- Any red line after the first: the first is the name, drawn in the quality's color.
local function usableFromTooltip(info)
    for i, line in ipairs(tooltipLines(info)) do
        if i > 1 and isRed(line) then return false end
    end
    return true
end

--- Whether the player can use the item: the client's answer, else no red tooltip line (B14). Lazy.
--- @param info table
--- @return boolean
function II.Usable(info)
    if info.usable == nil then
        local v = Compat.CanUseItem(info.id)
        if v == nil then v = usableFromTooltip(info) end
        info.usable = v
    end
    return info.usable
end

-- ── identity and comparison ───────────────────────────────────────────────────────────────────

-- The fields an exact match compares, each with the canonical value a record without it reads.
-- `diff` is compared for both callers, which unifies the legacy FindItem and ItemsAreSame.
local EXACT_FIELDS = { "suffix", "enchant", "gems", "uid", "upType", "diff", "bonus", "mods", "azerite" }
local DEFAULTS = { suffix = 0, enchant = 0, gems = "0:0:0:0", uid = 0, upType = 0, diff = 0,
                   bonus = "", mods = "", azerite = "" }

local function field(item, k)
    local v = item[k]
    if v == nil then return DEFAULTS[k] end
    return v
end

--- Whether two items (infos or records) are the same exact copy: every EXACT field equal.
--- @param a table
--- @param b table
--- @return boolean
function II.Exact(a, b)
    for _, k in ipairs(EXACT_FIELDS) do
        if field(a, k) ~= field(b, k) then return false end
    end
    return true
end

--- Whether two items are the same item: the same id and suffix, or `a`'s alias is `b`.
--- @param a table
--- @param b table
--- @return boolean
function II.SameIdentity(a, b)
    if a.id == b.id then return field(a, "suffix") == field(b, "suffix") end
    return NS.ItemData.ALIASES[a.id] == b.id
end

-- The keys of an ItemRecord (design §3.3).
local RECORD_KEYS = { "id", "suffix", "enchant", "gems", "uid", "upType", "diff", "bonus", "mods", "azerite",
                      "link", "name", "invType", "quality", "level" }

--- The single empty-slot marker an outfit stores (design §3.3).
II.EMPTY = { id = 0 }

--- The storable ItemRecord of an info: only the canonical keys, the link only when it is plain.
--- @param info table
--- @return table
function II.Snapshot(info)
    local rec = {}
    for _, k in ipairs(RECORD_KEYS) do rec[k] = info[k] end
    rec.link = Secrets.PlainString(info.link)
    return rec
end

--- Whether a two-hander takes both weapon slots: always, unless the player grips one in each hand.
--- @param item table
--- @return boolean
function II.UsesBothHands(item)
    return item.invType == "INVTYPE_2HWEAPON" and not NS.PlayerState.CanDualWield2H()
end

--- The meta slot the optimizer pairs the item on (Outfitter.lua:4026): a gripped two-hander pairs
--- like a one-hander.
--- @param item table
--- @return string|nil
function II.MetaSlot(item)
    local meta = item.meta
    if meta == nil then
        local slot = item.invType and NS.ItemData.INVTYPE_TO_SLOT[item.invType]
        meta = slot and slot.meta
    end
    if meta == "TwoHandSlot" and not II.UsesBothHands(item) then return "Weapon0Slot" end
    return meta
end

-- ── /of iteminfo ──────────────────────────────────────────────────────────────────────────────

local INFO_FIELDS = { "id", "name", "enchant", "gems", "suffix", "uid", "upType", "diff", "bonus", "mods" }

--- The lines `/of iteminfo` prints for a link: the link, then each parsed field. Every value goes
--- through NS.SafeToString, so a secret prints as the sentinel and never raises.
--- @param link any
--- @return string[]
function II.LinkInfoLines(link)
    local lines = { "link: " .. NS.SafeToString(link) }
    local fields, name = II.ParseLink(link)
    if not fields then
        lines[2] = L["Not a readable item link."]
        return lines
    end
    fields.name = name
    for _, k in ipairs(INFO_FIELDS) do
        lines[#lines + 1] = k .. ": " .. NS.SafeToString(fields[k])
    end
    return lines
end
