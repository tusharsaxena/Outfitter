local _, NS = ...
-- modules/Outfits_Seed.lua — LoadPass: repairing the store and seeding the built-in outfits, and the
-- 1 s timer that runs the first one (design §5.7). Extends NS.Outfits (modules/Outfits.lua).
--
-- REPAIR runs on every pass: the recents, the stack and the key bindings lose ids that no longer
-- exist, nextID is re-asserted above every stored id, every record is re-categorized into its order,
-- and the Argent Lance alias follows the player's faction.
--
-- SEED runs while char.seeded is not true (the first login, and after Delete all): the Equipment
-- Manager sync, Normal from the worn gear (and the stack set to it), Naked, one outfit per spec and
-- the class outfits, in the legacy order (tests/fixtures/legacy/states.lua: the spec outfits come
-- before the class ones, Outfitter.lua:5764-5770). Every seeded record carries its `builtin` key, and
-- an outfit that already has a built-in's name is adopted rather than duplicated (the legacy
-- CreateEmptySpecialOccasionOutfit, Outfitter.lua:5738). Profession smart outfits stay dead (INV §18).
--
-- THE TIMER is O.loadTimer, a 1 s AceTimer armed by the FIRST PLAYER_ENTERING_WORLD. Suspend
-- cancels it; Resume re-arms it only when that PEW was seen and the first LoadPass has not run
-- (design §5.12).
--
-- CALLS (at call time, no nil guard; design §12): NS.EM.Sync, NS.Stack.Init, NS.TriggerBinder.BindAll
-- and NS.OnLoadPassDone (core/OutfitterReborn.lua, after the session's first pass).

local O = NS.Outfits
local Compat, Secrets = NS.Compat, NS.Secrets
local L = NS.L
local ID = NS.ItemData

local LOAD_DELAY = 1   -- seconds after the first PLAYER_ENTERING_WORLD (C32)

-- The class outfits (Outfitter.lua:1058-1107): the name, and the trigger each now carries (§6.8.3).
local SEED_CLASS = {
    DRUID = {
        { L["Druid: Caster Form"], "DRUID_CASTER" },
        { L["Druid: Bear Form"], "DRUID_BEAR" },
        { L["Druid: Cat Form"], "DRUID_CAT" },
        { L["Druid: Travel Form"], "DRUID_TRAVEL" },
        { L["Druid: Moonkin Form"], "DRUID_MOONKIN" },
        { L["Druid: Tree of Life"], "DRUID_TREE" },
        { L["Druid: Prowl"], "DRUID_PROWL" },
    },
    ROGUE  = { { L["Rogue: Stealth"], "ROGUE_STEALTH" } },
    SHAMAN = { { L["Shaman: Ghost Wolf"], "SHAMAN_GHOST_WOLF" } },
}

local function store() return NS.db.char end

-- ── repair ────────────────────────────────────────────────────────────────────────────────────

local function pruneRecent(c)
    local seen, out = {}, {}
    for _, id in ipairs(c.recent) do
        if O.Get(id) and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    c.recent = out
end

local function pruneStack(c)
    local out = {}
    for _, entry in ipairs(c.stack) do
        if type(entry) == "table" and (entry.temp or O.Get(entry.id)) then out[#out + 1] = entry end
    end
    c.stack = out
end

local function pruneBindings(c)
    for n, id in pairs(c.bindings) do
        if not O.Get(id) then c.bindings[n] = nil end
    end
end

local function reassertNextID(c)
    local max = 0
    for id in pairs(c.outfits) do
        local n = tonumber(tostring(id):match("^o(%d+)$"))
        if n and n > max then max = n end
    end
    if c.nextID == nil or c.nextID <= max then c.nextID = max + 1 end
end

--- Rebuild both orders: the stored order first (stale ids and duplicates dropped), then any record
--- the orders missed, by id; every record lands in the order its category says.
local function rebuildOrders(c)
    local seen, ids = {}, {}
    for _, cat in ipairs(O.Categories()) do
        for _, id in ipairs(c.order[cat] or {}) do
            if O.Get(id) and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
    end
    local rest = {}
    for id in pairs(c.outfits) do
        if O.Get(id) and not seen[id] then rest[#rest + 1] = id end
    end
    table.sort(rest, function(a, b) return tonumber(a:sub(2)) < tonumber(b:sub(2)) end)
    for _, id in ipairs(rest) do ids[#ids + 1] = id end
    c.order = { Complete = {}, Accessory = {} }
    for _, id in ipairs(ids) do
        local rec = O.Get(id)
        rec.category = nil
        O.__place(rec)
    end
end

local function repair()
    local c = store()
    pruneRecent(c)
    pruneStack(c)
    pruneBindings(c)
    reassertNextID(c)
    rebuildOrders(c)
    ID.ApplyFactionAliases(Compat.PlayerFaction())
end

-- ── seed ──────────────────────────────────────────────────────────────────────────────────────

--- The id of the outfit seeded under `builtin`, or of one already named `name`.
local function existing(builtin, name)
    for id, rec in pairs(store().outfits) do
        if rec.builtin == builtin and O.Get(id) then return id end
    end
    return O.FindByName(name)
end

--- Seed one outfit unless it exists. An adopted outfit takes the trigger when it has none.
local function seedOne(builtin, name, items, opts)
    local id = existing(builtin, name)
    if not id then
        opts.builtin = builtin
        return O.Create(name, items, opts)
    end
    local rec = O.Get(id)
    if opts.trigger and not rec.trigger then rec.trigger = { id = opts.trigger } end
    return id
end

local function wornItems()
    local items = {}
    for _, slot in ipairs(ID.SLOT_NAMES) do
        local info = NS.ItemInfo.FromSlot(slot)
        items[slot] = info and NS.ItemInfo.Snapshot(info) or { id = 0 }
    end
    return items
end

local function nakedItems()
    local items = {}
    for _, slot in ipairs(ID.SLOT_NAMES) do items[slot] = { id = 0 } end
    return items
end

--- One outfit per specialization, "<Class>: <Spec>" with the spec's icon (Outfitter.lua:5776-5800);
--- done when the names run out, as the legacy loop was.
local function seedSpecs()
    local className = Compat.PlayerClassName() or ""
    for i = 1, Compat.NumSpecializations() do
        local _, specName, _, icon = Compat.GetSpecializationInfo(i)
        specName = Secrets.PlainString(specName)
        if not specName then return end
        seedOne("SPEC_" .. i, className .. ": " .. specName, {},
            { trigger = "SPEC_" .. i, icon = Secrets.PlainNumber(icon) })
    end
end

local function seedClass()
    for _, row in ipairs(SEED_CLASS[Compat.PlayerClass()] or {}) do
        seedOne("CLASS_" .. row[2], row[1], {}, { trigger = row[2] })
    end
end

local function seed()
    local c = store()
    NS.EM.Sync()
    local normal = seedOne("NORMAL", L["Normal"], wornItems(), {})
    c.stack = { { id = normal } }
    seedOne("NAKED", L["Birthday Suit"], nakedItems(), {})
    seedSpecs()
    seedClass()
    c.seeded = true
end

local firstDone = false   -- the session's first LoadPass has run
local pewSeen = false     -- the first PLAYER_ENTERING_WORLD has been seen

--- Repair, seed when unseeded, restore the stack and bind the triggers. Runs from the 1 s timer
--- after the first PLAYER_ENTERING_WORLD, and from DeleteAll.
function O.LoadPass()
    repair()
    if store().seeded ~= true then seed() end
    NS.Stack.Init()
    NS.TriggerBinder.BindAll()
    if not firstDone then
        firstDone = true
        NS.OnLoadPassDone()
    end
end

-- ── the timer and the lifecycle ───────────────────────────────────────────────────────────────

local events, timers

local function cancel()
    if O.loadTimer then timers:CancelTimer(O.loadTimer) end
    O.loadTimer = nil
end

local function fire()
    O.loadTimer = nil
    if NS.IsStoodDown() then return end
    O.LoadPass()
end

local function arm()
    cancel()
    O.loadTimer = timers:ScheduleTimer(fire, LOAD_DELAY)
end

local function onEnteringWorld()
    if NS.IsStoodDown() or pewSeen then return end
    pewSeen = true
    if not firstDone then arm() end
end

local function ensure()
    events = events or LibStub("AceEvent-3.0"):Embed({})
    timers = timers or LibStub("AceTimer-3.0"):Embed({})
end

--- The stand-down (design §5.12): the registration goes and the pending LoadPass is canceled.
function O.Suspend()
    if events then events:UnregisterAllEvents() end
    if timers then cancel() end
end

--- The stand-up: register from scratch, and re-arm the LoadPass a stand-down canceled.
function O.Resume()
    ensure()
    O.Suspend()
    NS.SafeRegisterEvent(events, "PLAYER_ENTERING_WORLD", onEnteringWorld, NS.rejectedEvents)
    if pewSeen and not firstDone then arm() end
end
