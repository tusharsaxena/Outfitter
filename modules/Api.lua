local _, NS = ...
-- modules/Api.lua — the public API, _G.OutfitterReborn.API.v1 (design §5.16, H3).
--
-- THE ONE GLOBAL another addon may call. Every legacy `Outfitter_*` function, the `Outfitter` table,
-- the `OutfitterItemList_*` pair and `Outfitter_GenerateSmartOutfit` are gone and are NOT shimmed
-- (H3; INV §10.3's shim rule is superseded). The v1 equivalents: FindOutfitByName, WearOutfit,
-- RemoveOutfit, GetCurrentOutfitInfo, GetOutfitsUsingItem, RegisterOutfitEvent and
-- UnregisterOutfitEvent. Third-party stat categories are dropped (O42), so there is no
-- RegisterStatCategory and no FindOutfitByStatID.
--
-- CONTRACT. No member raises: before the saved data exists (a caller at its own load) each answers
-- its empty value. An outfit reaches a caller only as a fresh copy, so no write to an answer can
-- reach the store. While the addon is stood down the two wear calls refuse (disabled means not
-- running, design §5.12); the reads still answer.
--
-- EVENTS. One bus receiver, made from the bus record on the first subscription, hears the six outfit
-- messages and calls each subscriber as fn(event, id, ...): event is the catalog key
-- ("OUTFIT_ADDED"), never the wire name, and `...` is the rest of the message's payload (the name of a
-- deleted outfit; the old and new names of a rename). Each call is xpcall-isolated and a raise goes to
-- the client's error handler; a returned value is ignored, never an error (INV §6.4's Fix). The bus
-- record drops the receiver at a stand-down and replays it at the stand-up.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.FindByName/Get/UsingItem and
-- NS.Stack.Wear/Remove/CurrentInfo.

local API = {}

-- INV §6.4's ADD/DELETE/RENAME/WEAR/UNWEAR/EDIT set. OUTFITTER_INIT has no equivalent.
local EVENTS = { "OUTFIT_ADDED", "OUTFIT_DELETED", "OUTFIT_RENAMED", "OUTFIT_WORN", "OUTFIT_REMOVED",
                 "OUTFIT_EDITED" }

local subscribers = {}   -- array, in subscription order
local bus

local function ready()
    local db = NS.db
    return db ~= nil and db.char ~= nil
end

-- A fresh { id, name, category } for a live outfit, or nil.
local function view(id)
    local rec = NS.Outfits.Get(id)
    if not rec then return nil end
    return { id = id, name = rec.name, category = rec.category }
end

local function indexOf(fn)
    for i, f in ipairs(subscribers) do
        if f == fn then return i end
    end
    return nil
end

-- ── outfits ───────────────────────────────────────────────────────────────────────────────────

--- The outfit named `name`, compared case-insensitively, as a copy `{ id, name, category }`; nil when
--- no outfit has that name.
--- @param name string
--- @return table|nil
function API.FindOutfitByName(name)
    if not ready() then return nil end
    local id = NS.Outfits.FindByName(name)
    return id and view(id) or nil
end

local function act(method, name)
    if not ready() or NS.IsStoodDown() then return false end
    local id = NS.Outfits.FindByName(name)
    if not id then return false end
    -- hw = false: an addon's call is no hardware event, so it never changes the player's title.
    return NS.Stack[method](id, { hw = false }) == true
end

--- Wear the outfit named `name`. False for an unknown name or while the addon is stood down.
--- @param name string
--- @return boolean
function API.WearOutfit(name) return act("Wear", name) end

--- Take off the outfit named `name`. False for an unknown name, an outfit not worn, or while the addon
--- is stood down.
--- @param name string
--- @return boolean
function API.RemoveOutfit(name) return act("Remove", name) end

--- The current outfit: `""` when nothing is worn, "Custom" (localized) for a temporary outfit on top,
--- else the top outfit's name and its id.
--- @return string name
--- @return string|nil id
function API.GetCurrentOutfitInfo()
    if not ready() then return "" end
    return NS.Stack.CurrentInfo()
end

--- The outfits that use the item, as copies `{ id, name }`. A secret or unparsable link answers none.
--- @param link any
--- @return table[]
function API.GetOutfitsUsingItem(link)
    local out = {}
    if not ready() then return out end
    for _, id in ipairs(NS.Outfits.UsingItem(link)) do
        local v = view(id)
        if v then out[#out + 1] = { id = v.id, name = v.name } end
    end
    return out
end

-- ── events ────────────────────────────────────────────────────────────────────────────────────

local function traceback(err)
    local ds = _G.debugstack
    if type(ds) == "function" then return tostring(err) .. "\n" .. tostring(ds(2)) end
    return debug.traceback(tostring(err), 2)
end

local function report(err)
    local geh = _G.geterrorhandler
    local handler = type(geh) == "function" and geh()
    if handler then handler(err) end
end

-- A snapshot of the list, so a subscriber that unregisters (itself or another) mid-call changes the
-- next dispatch, not this one. Lua 5.1's xpcall forwards no arguments: they travel in a closure.
local function dispatch(key, ...)
    local n, args = select("#", ...), { ... }
    local list = { unpack(subscribers) }
    for _, fn in ipairs(list) do
        local ok, err = xpcall(function() fn(key, unpack(args, 1, n)) end, traceback)
        if not ok then report(err) end
    end
end

-- The receiver: once per session, from the bus record. False without AceEvent (no bus target).
local function install()
    if bus then return true end
    bus = NS.NewBusTarget()
    if not bus then return false end
    for _, key in ipairs(EVENTS) do
        bus:RegisterMessage(NS.MSG[key], function(_, ...) dispatch(key, ...) end)
    end
    return true
end

--- Call `fn(event, id, ...)` for each outfit message. A second Register of one function is the same
--- subscription. False for a non-function, or when the event bus is unavailable.
--- @param fn function
--- @return boolean
function API.RegisterOutfitEvent(fn)
    if type(fn) ~= "function" or not install() then return false end
    if not indexOf(fn) then subscribers[#subscribers + 1] = fn end
    return true
end

--- Stop calling `fn`. False when it was not subscribed.
--- @param fn function
--- @return boolean
function API.UnregisterOutfitEvent(fn)
    local i = indexOf(fn)
    if not i then return false end
    table.remove(subscribers, i)
    return true
end

OutfitterReborn = { API = { v1 = API } }
