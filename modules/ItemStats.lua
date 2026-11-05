local _, NS = ...
-- modules/ItemStats.lua — NS.Stats: the stats the optimizer scores items by (design §5.14).
--
-- THE BUILT-IN CATEGORY ("Stat") holds the nine item stats, TOTAL_STATS and ITEM_LEVEL. An item's
-- stats are C_Item.GetItemStats' tokens (Compat.ItemStats) mapped through STAT_KEYS, and its level is
-- Compat.DetailedItemLevel. Each label is the client's own GlobalString for the stat's token, read by
-- name, so every locale scores and reads every stat (B13: the legacy library matched English tooltip
-- text, and VER, CRI and ITEM_LEVEL never scored on a non-English client).
--
-- ADAPTIVE GEAR (O20). An item whose primary changes with the spec carries ONE combined key
-- (ITEM_MOD_STRENGTH_AGILITY_INTELLECT_SHORT and the two-primary forms). Each primary's alias list
-- names the combined keys that include it, so STR, AGI and INT all read it, and TOTAL_STATS counts
-- every distinct key once, so the combined line is not summed three times. SPI is kept for parity
-- with the legacy list; current items carry none, so it scores 0.
--
-- THE LEVEL FILTER (INV §3.6). An item whose minimum level is above the player's is dropped: Score
-- answers nil, which a caller reads as "not a candidate". The player's level goes through the
-- Secrets seam; a secret (unreadable) level lets the item through rather than silently dropping it.
--
-- THE CACHE. stat:Score(info, job) keeps its answer on `job.scores`, keyed weakly by the info, so a
-- search that scores one item many times reads the client once, and nothing outlives the job.
--
-- CATEGORIES. RegisterCategory is the addon's own: the Pawn and WeightsWatcher sources
-- (modules/ItemStats_Sources.lua) are its only callers, and the built-in category is never replaced.
-- The legacy third-party path (a global category list walked by stat count and index, INV §10.2) is
-- dropped with the Outfitter global (H3), and no alias is kept (§5.16).

local Stats = {}
NS.Stats = Stats

local Compat, Secrets = NS.Compat, NS.Secrets
local L = NS.L

-- ── the stat table ────────────────────────────────────────────────────────────────────────────

local ALL3 = "ITEM_MOD_STRENGTH_AGILITY_INTELLECT_SHORT"
local STR_AGI, STR_INT, AGI_INT =
    "ITEM_MOD_STRENGTH_AGILITY_SHORT", "ITEM_MOD_STRENGTH_INTELLECT_SHORT", "ITEM_MOD_AGILITY_INTELLECT_SHORT"

-- In display order. The first key of each list is the stat's own token and its label.
local STAT_KEYS = {
    { "STA", { "ITEM_MOD_STAMINA_SHORT" } },
    { "STR", { "ITEM_MOD_STRENGTH_SHORT", ALL3, STR_AGI, STR_INT } },
    { "INT", { "ITEM_MOD_INTELLECT_SHORT", ALL3, STR_INT, AGI_INT } },
    { "AGI", { "ITEM_MOD_AGILITY_SHORT", ALL3, STR_AGI, AGI_INT } },
    { "SPI", { "ITEM_MOD_SPIRIT_SHORT" } },
    { "HAS", { "ITEM_MOD_HASTE_RATING_SHORT" } },
    { "VER", { "ITEM_MOD_VERSATILITY" } },
    { "MAS", { "ITEM_MOD_MASTERY_RATING_SHORT" } },
    { "CRI", { "ITEM_MOD_CRIT_RATING_SHORT" } },
}

-- Every key some stat reads: what TOTAL_STATS sums, each key once.
local TOTAL_KEYS = {}
for _, row in ipairs(STAT_KEYS) do
    for _, key in ipairs(row[2]) do TOTAL_KEYS[key] = true end
end

-- The client's GlobalString `key`, or `fallback` when the client has none.
local function globalLabel(key, fallback)
    local v = _G[key]
    if type(v) == "string" and v ~= "" then return v end
    return fallback
end

-- ── item stats ────────────────────────────────────────────────────────────────────────────────

-- The first alias present in `raw`, or nil.
local function firstOf(raw, keys)
    for _, key in ipairs(keys) do
        if raw[key] then return raw[key] end
    end
    return nil
end

local function totalOf(raw)
    local sum = 0
    for key, value in pairs(raw) do
        if TOTAL_KEYS[key] then sum = sum + value end
    end
    return sum
end

--- `{ values = { [statID] = n }, minLevel = n|nil }` for `link`, or nil when the link is unreadable
--- (absent, secret). A stat the item lacks is absent from values. Stats the client cannot answer
--- (not cached yet, or sealed) read as none, so the item still scores 0 on them and keeps its
--- ITEM_LEVEL, which is read on its own: the legacy library always answered a stats object, and
--- its score was `GetUncachedItemScore(item) or 0` (OutfitterItemStats.lua:148 at 7ea3dc3).
function Stats.ItemStats(link)
    link = Secrets.PlainString(link)
    if not link then return nil end
    local raw = Compat.ItemStats(link) or {}
    local values = {}
    for _, row in ipairs(STAT_KEYS) do values[row[1]] = firstOf(raw, row[2]) end
    values.TOTAL_STATS = totalOf(raw)
    values.ITEM_LEVEL = Compat.DetailedItemLevel(link)
    local _, _, _, minLevel = Compat.ItemInfo(link)
    return { values = values, minLevel = minLevel }
end

-- ── stats and scores ──────────────────────────────────────────────────────────────────────────

local StatProto = {}
StatProto.__index = StatProto

-- Whether the item asks for more than the player's level. An unreadable level (secret, or no
-- client) is not a reason to drop it.
local function tooHigh(info, link)
    local minLevel = Secrets.PlainNumber(info.minLevel)
    if minLevel == nil then
        local _, _, _, fromClient = Compat.ItemInfo(link)
        minLevel = fromClient
    end
    local level = Secrets.PlainNumber(Compat.UnitLevel("player"))
    return minLevel ~= nil and level ~= nil and minLevel > level
end

local function uncachedScore(stat, info)
    local link = Secrets.PlainString(info.link)
    if not link or tooHigh(info, link) then return nil end
    return stat.score(info, link)
end

-- The job's score cache, made on first use: [info] = { [stat] = score, or false for nil }.
local WEAK_KEYS = { __mode = "k" }
local function cacheOf(job)
    local scores = job.scores
    if not scores then
        scores = setmetatable({}, WEAK_KEYS)
        job.scores = scores
    end
    return scores
end

--- The item's score on this stat: a number, or nil when the item is dropped (unreadable, or above
--- the player's level). With `job`, the answer is kept on job.scores for the length of the job.
function StatProto:Score(info, job)
    if type(info) ~= "table" then return nil end
    if not job then return uncachedScore(self, info) end
    local cache = cacheOf(job)
    local row = cache[info]
    if row and row[self] ~= nil then return row[self] or nil end
    local score = uncachedScore(self, info)
    if not row then
        row = {}
        cache[info] = row
    end
    row[self] = score == nil and false or score
    return score
end

--- A stat: `id` (unique across every category), `label` (shown), and `score(info, link)` answering
--- a number. The level filter and the cache wrap it; it is never handed an unreadable link.
function Stats.NewStat(id, label, score)
    return setmetatable({ id = id, label = label, score = score }, StatProto)
end

local function builtinScore(id)
    return function(_, link)
        local s = Stats.ItemStats(link)
        if not s then return nil end
        return s.values[id] or 0
    end
end

local BUILTIN_STATS = {}
for _, row in ipairs(STAT_KEYS) do
    local id, token = row[1], row[2][1]
    BUILTIN_STATS[#BUILTIN_STATS + 1] = Stats.NewStat(id, globalLabel(token, id), builtinScore(id))
end
BUILTIN_STATS[#BUILTIN_STATS + 1] = Stats.NewStat("TOTAL_STATS", L["Total stats"], builtinScore("TOTAL_STATS"))
BUILTIN_STATS[#BUILTIN_STATS + 1] = Stats.NewStat("ITEM_LEVEL", L["Item level"], builtinScore("ITEM_LEVEL"))

-- ── categories ────────────────────────────────────────────────────────────────────────────────

-- A category: { id, label, stats = function() -> stat[] }. A function, so a source whose list can
-- change (Pawn's visible scales) answers its current one.
-- The label is the client's own PLAYERSTAT_BASE_STATS (the legacy Name), so every locale reads it.
local BUILTIN = { id = "Stat", label = globalLabel("PLAYERSTAT_BASE_STATS", L["Base stats"]),
                  stats = function() return BUILTIN_STATS end }
local categories = { BUILTIN }

--- The registered categories, built-in first. A fresh array; the categories are the live ones.
function Stats.Categories()
    local out = {}
    for i, c in ipairs(categories) do out[i] = c end
    return out
end

local function validCategory(cat)
    return type(cat) == "table" and type(cat.id) == "string" and type(cat.label) == "string"
        and type(cat.stats) == "function"
end

--- Add `cat`, or replace the registered category with its id. Nothing is announced: the Rebuild
--- dialog reads Categories() when it opens. Refused (false) for a malformed category and for the
--- built-in's id: the built-in is never replaced.
function Stats.RegisterCategory(cat)
    if not validCategory(cat) or cat.id == BUILTIN.id then return false end
    local slot = #categories + 1
    for i, c in ipairs(categories) do
        if c.id == cat.id then slot = i end
    end
    categories[slot] = cat
    return true
end

--- The stat with id `statID` in any category, or nil.
function Stats.Get(statID)
    if type(statID) ~= "string" then return nil end
    for _, c in ipairs(categories) do
        for _, stat in ipairs(c.stats()) do
            if stat.id == statID then return stat end
        end
    end
    return nil
end

--- The labels of a cfg's stats ("Stamina, Haste"), or nil when cfg is empty or names a stat that
--- no longer exists (a Pawn scale since deleted).
function Stats.ConfigName(cfg)
    if type(cfg) ~= "table" or #cfg == 0 then return nil end
    local names = {}
    for i, row in ipairs(cfg) do
        local stat = Stats.Get(row.stat)
        if not stat then return nil end
        names[i] = stat.label
    end
    return table.concat(names, ", ")
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────
-- The module's only registration is the sources' ADDON_LOADED watch (design §5.12). Called at call
-- time: modules/ItemStats_Sources.lua loads after this file.

function Stats.Suspend() NS.StatSources.Suspend() end

function Stats.Resume() NS.StatSources.Resume() end
