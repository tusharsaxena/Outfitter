-- tests/mock_gear.lua — the equipment half of the client (design §9.2 "mock_gear"): worn items,
-- bags, the bank, the cursor, item info and C_EquipmentSet, all answering from
-- tests/fixtures/items.lua and moving items FOR REAL.
--
-- Installed by tests/wow_mock.lua on every fresh mock: `install(M, deps)` with
-- deps = { items = <fixtures/items.lua>, inventories = <fixtures/inventories.lua>, secret = Kit.secret,
-- sets = <tests/mock_gear_sets.lua> } (C_EquipmentSet, a file of its own for the line budget).
-- It publishes the controller as `M.__gear`; a suite drives the client through it:
--
--   M.__gear:load("full_bags" [, overrides])   a named scenario (fixtures/inventories.lua)
--   M.__gear:equipped("HeadSlot")              the instance worn there, or nil
--   M.__gear:bagItem(bag, slot)                the instance in a bag slot, or nil
--   M.__gear:where(inst)                       { equip = slotID } | { bag = b, slot = s } | nil
--   M.__gear:find(key)                         the first instance of a fixture key, and where
--   M.__gear:openBank() / :closeBank()         the bank frame (fires the client's events now)
--   M.__gear:resolve(key)                      a pending item's info arrives (GET_ITEM_INFO_RECEIVED)
--   M.__gear:deliver()                         the events the last actions caused, in order
--   M.__gear:tooltipLines(inst | def)          the lines the client would draw for it
--
-- THE FIDELITY RULES this file keeps (testing-§1):
--   * Plans move items. PickupContainerItem, PickupInventoryItem, EquipCursorItem, PutItemIn*,
--     UseContainerItem and C_EquipmentSet.UseEquipmentSet change what is worn and carried, with the
--     client's swap, two-hander, unique-equipped, specialty-bag and bag-full rules. Every call is
--     recorded, in order, in `M.__equipCalls` as { name, args... }.
--   * A refused move leaves the item on the cursor and records the client's error key in
--     `M.__gearErrors` (ERR_INV_FULL, ERR_BAG_FULL, ERR_WRONG_SLOT, ERR_ITEM_UNIQUE_EQUIPPABLE,
--     ERR_ITEM_DOESNT_GO_INTO_BAG, ERR_CANT_EQUIP_LEVEL_I), as the client prints and keeps it.
--   * EVENTS ARRIVE LATER, as in the client: a move queues BAG_UPDATE, PLAYER_EQUIPMENT_CHANGED,
--     UNIT_INVENTORY_CHANGED and BAG_UPDATE_DELAYED, and nothing fires until `:deliver()`. A
--     handler that re-entered the planner mid-plan would otherwise be tested on a path the client
--     never takes.
--   * A `secret = true` fixture's links are a fresh Kit.secret wrapper on every read (worn, bag,
--     item location, tooltip text), so the only safe thing to do with one is to hand it to the seam.
--   * The bank's contents are unreadable while it is closed (no slots, no links), unless a suite
--     sets `M.__gear.bankCached = true` to model the client's cache. C_EquipmentSet still knows
--     where a banked set item is, as the client does.
--   * C_EquipmentSet keeps real sets that follow their items as they move; `M.__emFlake = true`
--     makes it answer zero sets without forgetting them (Q8), and clearing the flag restores them.
--
-- Client checks still owed (design §5.13, O17): the shape of C_Item.GetItemUniquenessByID's answer
-- for a limit category, and whether a banked set item's location carries the BANK bit; the mock
-- answers (true, name, count, id) and BAGS-only, which is what the legacy code defended against.

local Gear = {}

-- ── slots ────────────────────────────────────────────────────────────────────────────────────

local SLOT_IDS = {
    HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5, WaistSlot = 6,
    LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10, Finger0Slot = 11, Finger1Slot = 12,
    Trinket0Slot = 13, Trinket1Slot = 14, BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17,
    TabardSlot = 19,
}
local SLOT_NAMES = {}
for name, id in pairs(SLOT_IDS) do SLOT_NAMES[id] = name end
local EQUIP_IDS = {}
for id in pairs(SLOT_NAMES) do EQUIP_IDS[#EQUIP_IDS + 1] = id end
table.sort(EQUIP_IDS)
Gear.SLOT_IDS, Gear.SLOT_NAMES, Gear.EQUIP_IDS = SLOT_IDS, SLOT_NAMES, EQUIP_IDS

local MH, OH = 16, 17
local FITS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { MH, OH },
    INVTYPE_SHIELD = { OH }, INVTYPE_2HWEAPON = { MH, OH }, INVTYPE_WEAPONMAINHAND = { MH },
    INVTYPE_WEAPONOFFHAND = { OH }, INVTYPE_HOLDABLE = { OH }, INVTYPE_RANGED = { MH },
    INVTYPE_RANGEDRIGHT = { MH }, INVTYPE_THROWN = { MH }, INVTYPE_TABARD = { 19 },
}
Gear.FITS = FITS
-- Two-handed for the purpose of the off hand: a bow occupies both hands like a greatsword.
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }

-- ── bags ─────────────────────────────────────────────────────────────────────────────────────

local BACKPACK, LAST_BAG, REAGENT_BAG = 0, 4, 5
local BANK_FIRST, BANK_LAST, ACCOUNT_FIRST, ACCOUNT_LAST = 6, 11, 12, 16
local CONTAINER_BAG_OFFSET = 30
local PLAYER_BIT, BAGS_BIT, BANK_BIT = 0x00100000, 0x00200000, 0x00400000
Gear.LOCATION = { PLAYER = PLAYER_BIT, BAGS = BAGS_BIT, BANK = BANK_BIT,
                  EMPTY = 0, IGNORED = 1, MISSING = -1 }

local function isBankBag(bag) return type(bag) == "number" and bag >= BANK_FIRST and bag <= ACCOUNT_LAST end

-- Whether two bag-family masks share a bit (Lua 5.1 has no bit operators).
local function sharesBit(a, b)
    a, b = a or 0, b or 0
    local bit = 1
    while bit <= a and bit <= b do
        if a % (bit * 2) >= bit and b % (bit * 2) >= bit then return true end
        bit = bit * 2
    end
    return false
end
Gear.sharesBit = sharesBit

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 }, [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 },
}
local CLASS_NAMES = { [1] = "Container", [2] = "Weapon", [4] = "Armor", [7] = "Tradeskill",
                      [15] = "Miscellaneous" }

-- The client strings the item code reads (GlobalStrings), as the enUS client has them.
local STRINGS = {
    ITEM_SOULBOUND = "Soulbound", ITEM_BIND_ON_EQUIP = "Binds when equipped",
    ITEM_BIND_ON_PICKUP = "Binds when picked up", ITEM_ACCOUNTBOUND_UNTIL_EQUIP = "Warbound until equipped",
    ITEM_UNIQUE_EQUIPPABLE = "Unique-Equipped", ITEM_LIMIT_CATEGORY_MULTIPLE = "Unique-Equipped: %s (%d)",
    ITEM_SPELL_TRIGGER_ONUSE = "Use:",
    HEADSLOT = "Head", NECKSLOT = "Neck", SHOULDERSLOT = "Shoulder", BACKSLOT = "Back",
    CHESTSLOT = "Chest", SHIRTSLOT = "Shirt", TABARDSLOT = "Tabard", WRISTSLOT = "Wrist",
    HANDSSLOT = "Hands", WAISTSLOT = "Waist", LEGSSLOT = "Legs", FEETSLOT = "Feet",
    FINGER0SLOT = "Finger", FINGER1SLOT = "Finger", TRINKET0SLOT = "Trinket", TRINKET1SLOT = "Trinket",
    MAINHANDSLOT = "Main Hand", SECONDARYHANDSLOT = "Off Hand",
    ERR_INV_FULL = "Inventory is full.", ERR_BAG_FULL = "That bag is full.",
    ERR_WRONG_SLOT = "That item doesn't go in that slot.",
    ERR_ITEM_UNIQUE_EQUIPPABLE = "You can't equip more than one of those.",
    ERR_ITEM_DOESNT_GO_INTO_BAG = "That item doesn't go in that container.",
    ERR_CANT_EQUIP_LEVEL_I = "You must reach level %d to use that item.",
}
Gear.STRINGS = STRINGS

-- ── the installer ────────────────────────────────────────────────────────────────────────────

function Gear.install(M, deps)
    local Items, Scenarios, secret = deps.items, deps.inventories, deps.secret
    local G = { calls = {}, errors = {}, queue = {} }
    M.__gear, M.__equipCalls, M.__gearErrors = G, G.calls, G.errors
    M.__emFlake = false

    -- Fixture lookups: by id (the first key in sorted order, so a shared id answers stably), by
    -- link and by name.
    local byID, byLink, byName = {}, {}, {}
    for _, key in ipairs(Items.names) do
        local def = Items.db[key]
        byID[def.id] = byID[def.id] or def
        byLink[def.link] = def
        byName[def.name] = byName[def.name] or def
    end

    local function record(name, ...)
        G.calls[#G.calls + 1] = { name, ... }
    end
    local function fail(key)
        G.errors[#G.errors + 1] = key
        G.queue[#G.queue + 1] = { "UI_ERROR_MESSAGE", 0, STRINGS[key] or key }
        return false
    end
    local function queue(event, ...)
        G.queue[#G.queue + 1] = { event, ... }
    end

    -- ── state ────────────────────────────────────────────────────────────────────────────────

    local function newInst(spec)
        if spec == nil or spec == false then return nil end
        local key = type(spec) == "table" and spec.key or spec
        local def = assert(Items.db[key], "mock_gear: no fixture item " .. tostring(key))
        local o = type(spec) == "table" and spec or {}
        local bound = def.bindType == 1
        if o.bound ~= nil then bound = o.bound == true end
        local inst = { key = key, def = def, count = o.count or 1, bound = bound,
                       warbound = def.bindType == 9 and not bound, cooldown = o.cooldown, locked = false }
        if o.durability then inst.durability = { o.durability[1], o.durability[2] }
        elseif def.durability then inst.durability = { def.durability[1], def.durability[2] } end
        return inst
    end

    local function reset()
        G.worn, G.bags, G.cursor, G.sets, G.nextSetID = {}, {}, nil, {}, 1
        G.ignoreForSave, G.pending = {}, {}
        G.bankOpen, G.bankCached, G.titansGrip, G.canDualWield = false, false, false, true
        G.bags[BACKPACK] = { size = 16, family = 0, slots = {} }
        for k in pairs(G.calls) do G.calls[k] = nil end
        for k in pairs(G.errors) do G.errors[k] = nil end
        for k in pairs(G.queue) do G.queue[k] = nil end
    end
    reset()

    local function readable(bag)
        local b = G.bags[bag]
        if not b then return nil end
        if b.bank and not (G.bankOpen or G.bankCached) then return nil end
        return b
    end

    local function at(loc)
        if loc.equip then return G.worn[loc.equip] end
        local b = G.bags[loc.bag]
        return b and b.slots[loc.slot]
    end
    local function put(loc, inst)
        if loc.equip then G.worn[loc.equip] = inst else G.bags[loc.bag].slots[loc.slot] = inst end
    end
    local function where(inst)
        if inst == nil then return nil end
        for id, i in pairs(G.worn) do if i == inst then return { equip = id } end end
        for bag, b in pairs(G.bags) do
            for slot, i in pairs(b.slots) do if i == inst then return { bag = bag, slot = slot } end end
        end
        return nil
    end
    local function sameLoc(a, b)
        return a and b and a.equip == b.equip and a.bag == b.bag and a.slot == b.slot
    end
    local function touched(loc)
        if loc.equip then
            queue("PLAYER_EQUIPMENT_CHANGED", loc.equip, G.worn[loc.equip] == nil)
            queue("UNIT_INVENTORY_CHANGED", "player")
        else
            queue("BAG_UPDATE", loc.bag)
        end
    end

    local function accepts(bag, inst)
        local b = G.bags[bag]
        if not b then return false end
        if (b.family or 0) == 0 then return true end
        local def = inst.def
        return sharesBit(def.family or 0, b.family)
    end

    -- The first free slot that takes `inst`: specialty bags that fit it first, as the client
    -- fills them, then the general bags in order. Bank bags only when `bank` is asked for.
    local function takes(bag, b, inst, special)
        if not b or ((b.family or 0) ~= 0) ~= special then return false end
        if bag == REAGENT_BAG and inst.def.invType ~= "" then return false end
        return accepts(bag, inst)
    end
    local function firstEmpty(bag, b)
        for slot = 1, b.size do
            if b.slots[slot] == nil then return { bag = bag, slot = slot } end
        end
        return nil
    end
    local function freeSlot(inst, bank)
        local first, last = BACKPACK, REAGENT_BAG
        if bank then first, last = BANK_FIRST, BANK_LAST end
        for _, special in ipairs({ true, false }) do
            for bag = first, last do
                local b = readable(bag)
                local loc = takes(bag, b, inst, special) and firstEmpty(bag, b)
                if loc then return loc end
            end
        end
        return nil
    end

    -- ── equip rules ──────────────────────────────────────────────────────────────────────────

    local function fits(inst, slotID)
        local inv = inst.def.invType
        if slotID == OH and TWO_HAND[inv] then return G.titansGrip and inv == "INVTYPE_2HWEAPON" end
        if slotID == OH and inv == "INVTYPE_WEAPON" and not G.canDualWield then return false end
        for _, s in ipairs(FITS[inv] or {}) do if s == slotID then return true end end
        return false
    end

    local function uniqueKey(def)
        if def.unique == true then return "i" .. def.id, 1 end
        if type(def.unique) == "table" then return "c" .. def.unique.id, def.unique.count or 1 end
        return nil
    end

    -- Would wearing `inst` in `slotID` (its old occupant gone, `inst` lifted from `from`) exceed a
    -- unique-equipped limit?
    local function breaksUnique(inst, slotID, from)
        local key, limit = uniqueKey(inst.def)
        if not key then return false end
        local n = 1
        for id, worn in pairs(G.worn) do
            if id ~= slotID and not (from and from.equip == id) and uniqueKey(worn.def) == key then
                n = n + 1
            end
        end
        return n > limit
    end

    local function bindOnEquip(inst)
        if inst.def.bindType == 2 or inst.def.bindType == 9 then inst.bound = true end
        inst.warbound = false
    end

    -- The hand that must empty for `inst` to go in `slotID`, or nil.
    local function displacedHand(inst, slotID)
        if G.titansGrip then return nil end
        if slotID == MH and TWO_HAND[inst.def.invType] and G.worn[OH] then return OH end
        local main = G.worn[MH]
        if slotID == OH and main and TWO_HAND[main.def.invType] then return MH end
        return nil
    end

    local function clearCursor()
        if G.cursor then G.cursor.inst.locked = false end
        G.cursor = nil
    end

    -- The client's error key for wearing `inst` (lifted from `from`) in `slotID`, or nil.
    local function equipRefusal(inst, from, slotID)
        if not fits(inst, slotID) then return "ERR_WRONG_SLOT" end
        if inst.def.unusable then return "ERR_CANT_EQUIP_LEVEL_I" end
        if breaksUnique(inst, slotID, from) then return "ERR_ITEM_UNIQUE_EQUIPPABLE" end
        local old = G.worn[slotID]
        if old and from.equip and not fits(old, from.equip) then return "ERR_WRONG_SLOT" end
        return nil
    end

    -- The move itself, once nothing refuses it: the displaced hand to its bag slot, the old
    -- occupant to where the new item came from, both bound if they are now worn.
    local function commitEquip(inst, from, slotID, hand, handDest)
        local old = G.worn[slotID]
        put(from, nil)
        if handDest then
            put(handDest, G.worn[hand]); put({ equip = hand }, nil)
            touched(handDest); touched({ equip = hand })
        end
        put({ equip = slotID }, inst)
        if old then put(from, old) end
        bindOnEquip(inst)
        if old and from.equip then bindOnEquip(old) end
        clearCursor()
        touched(from); touched({ equip = slotID })
        queue("BAG_UPDATE_DELAYED")
    end

    -- Equip what is on the cursor into `slotID`, with the client's rules. The cursor item stays in
    -- its origin (locked) until the move commits, as the client holds it.
    local function equipFromCursor(slotID)
        local c = G.cursor
        if not c then return false end
        local inst, from = c.inst, c.from
        if sameLoc(from, { equip = slotID }) then clearCursor(); return true end
        local refused = equipRefusal(inst, from, slotID)
        if refused then return fail(refused) end
        local hand = displacedHand(inst, slotID)
        local handDest
        if hand and from.equip ~= hand then
            handDest = freeSlot(G.worn[hand])
            if not handDest then return fail("ERR_INV_FULL") end
        end
        commitEquip(inst, from, slotID, hand, handDest)
        return true
    end

    -- Drop what is on the cursor into a bag slot, swapping with what is there.
    local function dropInBag(loc)
        local c = G.cursor
        local inst, from = c.inst, c.from
        if sameLoc(from, loc) then clearCursor(); return true end
        if not accepts(loc.bag, inst) then return fail("ERR_ITEM_DOESNT_GO_INTO_BAG") end
        local target = at(loc)
        if target then
            if from.equip then
                if not fits(target, from.equip) then return fail("ERR_WRONG_SLOT") end
                if breaksUnique(target, from.equip, nil) then return fail("ERR_ITEM_UNIQUE_EQUIPPABLE") end
            elseif not accepts(from.bag, target) then
                return fail("ERR_ITEM_DOESNT_GO_INTO_BAG")
            end
        end
        put(from, target)
        put(loc, inst)
        if target and from.equip then bindOnEquip(target) end
        clearCursor()
        touched(from); touched(loc)
        queue("BAG_UPDATE_DELAYED")
        return true
    end

    local function lift(loc)
        local inst = at(loc)
        if not inst or inst.locked then return false end
        G.cursor = { inst = inst, from = loc }
        inst.locked = true
        return true
    end

    -- ── the controller ───────────────────────────────────────────────────────────────────────

    local function placeBag(bagID, spec)
        local b
        if bagID == BACKPACK then
            b = G.bags[BACKPACK]
        else
            local bagInst = newInst(spec.bag or "bag_backpack16")
            b = { size = bagInst.def.slots, family = bagInst.def.bagFamily or 0, bagInst = bagInst,
                  slots = {} }
            G.bags[bagID] = b
        end
        for slot, item in pairs(spec.items or {}) do
            assert(slot <= b.size, ("mock_gear: bag %d has %d slots, not %d"):format(bagID, b.size, slot))
            b.slots[slot] = newInst(item)
        end
    end

    local function placeBank(tab, spec)
        local b = { size = spec.size or 98, family = 0, bank = true, slots = {} }
        G.bags[tab] = b
        for slot, item in pairs(spec.items or {}) do b.slots[slot] = newInst(item) end
    end

    local function merge(name, overrides)
        local sc = type(name) == "table" and name
            or assert(Scenarios[name], "mock_gear: no scenario " .. tostring(name))
        local merged = {}
        for k, v in pairs(sc) do merged[k] = v end
        for k, v in pairs(overrides or {}) do merged[k] = v end
        return merged
    end

    function G:load(name, overrides)
        local sc = merge(name, overrides)
        reset()
        G.scenario = sc
        G.titansGrip, G.canDualWield = sc.titansGrip == true, sc.dualWield ~= false
        for slotName, key in pairs(sc.equipped or {}) do
            G.worn[assert(SLOT_IDS[slotName], "mock_gear: no slot " .. slotName)] = newInst(key)
        end
        for bagID, spec in pairs(sc.bags or {}) do placeBag(bagID, spec) end
        for tab, spec in pairs(sc.bank or {}) do placeBank(tab, spec) end
        G.bankOpen = sc.bankOpen == true
        for _, key in ipairs(sc.pending or {}) do G.pending[Items.db[key].id] = true end
        for _, set in ipairs(sc.sets or {}) do G:addSet(set) end
        if M.__world then M.__world:applyScenario(sc) end
        return G
    end

    function G:addSet(spec)
        local id = G.nextSetID
        G.nextSetID = id + 1
        local set = { id = id, name = spec.name, icon = spec.icon or 134400, items = {}, ignored = {} }
        for slotName, key in pairs(spec.items or {}) do
            local slotID = SLOT_IDS[slotName]
            if key == false then set.items[slotID] = false
            else set.items[slotID] = select(1, G:find(key)) or false end
        end
        for _, slotName in ipairs(spec.ignored or {}) do set.ignored[SLOT_IDS[slotName]] = true end
        G.sets[id] = set
        return id
    end

    function G:equipped(slotName) return G.worn[SLOT_IDS[slotName] or slotName] end
    function G:bagItem(bag, slot) local b = G.bags[bag]; return b and b.slots[slot] end
    function G:where(inst) return where(inst) end
    function G:find(key)
        for _, id in ipairs(EQUIP_IDS) do
            local i = G.worn[id]
            if i and i.key == key then return i, { equip = id } end
        end
        local bags = {}
        for bag in pairs(G.bags) do bags[#bags + 1] = bag end
        table.sort(bags)
        for _, bag in ipairs(bags) do
            local b = G.bags[bag]
            for slot = 1, b.size do
                local i = b.slots[slot]
                if i and i.key == key then return i, { bag = bag, slot = slot } end
            end
        end
        return nil
    end
    function G:freeSlots(bag)
        local b, n = G.bags[bag], 0
        if not b then return 0 end
        for slot = 1, b.size do if b.slots[slot] == nil then n = n + 1 end end
        return n
    end

    function G:deliver()
        local list, seenBag = G.queue, {}
        G.queue = {}
        local delayed = false
        for _, e in ipairs(list) do
            if e[1] == "BAG_UPDATE_DELAYED" then
                delayed = true
            elseif e[1] ~= "BAG_UPDATE" or not seenBag[e[2]] then
                if e[1] == "BAG_UPDATE" then seenBag[e[2]] = true end
                M.__fire(unpack(e))
            end
        end
        if delayed then M.__fire("BAG_UPDATE_DELAYED") end
        return #list
    end

    function G:openBank()
        G.bankOpen = true
        M.__fire("BANKFRAME_OPENED")
        M.__fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 8)
    end
    function G:closeBank()
        G.bankOpen = false
        M.__fire("BANKFRAME_CLOSED")
        M.__fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", 8)
    end
    function G:resolve(key)
        local id = Items.db[key] and Items.db[key].id or key
        G.pending[id] = nil
        M.__fire("GET_ITEM_INFO_RECEIVED", id, true)
    end

    -- ── links, secrets, item lookups ─────────────────────────────────────────────────────────

    local function linkOf(inst)
        if not inst then return nil end
        if inst.def.secret then return secret(inst.def.link) end
        return inst.def.link
    end

    local function defFor(item)
        if type(item) == "number" then return byID[item] end
        if type(item) ~= "string" then return nil end
        if byLink[item] then return byLink[item] end
        local id = item:match("item:(%-?%d+)")
        if id then return byID[tonumber(id)] end
        return byName[item]
    end
    G.defFor = defFor

    local function instAtLocation(loc)
        if type(loc) ~= "table" or not loc.__mockLoc then return nil end
        if loc.equipSlot then return G.worn[loc.equipSlot] end
        local b = readable(loc.bag)
        return b and b.slots[loc.slot]
    end

    function G:tooltipLines(obj)
        local inst = obj and obj.def and obj or nil
        local def = inst and inst.def or obj
        if not def then return {} end
        local function text(s) return def.secret and secret(s) or s end
        local q = QUALITY_COLORS[def.quality] or QUALITY_COLORS[1]
        local lines = { { leftText = text(def.name), leftColor = { r = q[1], g = q[2], b = q[3] } } }
        local function add(s, r, g, b) lines[#lines + 1] = { leftText = text(s), leftColor = { r = r, g = g, b = b } } end
        if inst and inst.bound then add(STRINGS.ITEM_SOULBOUND, 1, 1, 1)
        elseif def.bindType == 9 then add(STRINGS.ITEM_ACCOUNTBOUND_UNTIL_EQUIP, 0, 0.8, 1)
        elseif def.bindType == 2 then add(STRINGS.ITEM_BIND_ON_EQUIP, 1, 1, 1)
        elseif def.bindType == 1 then add(STRINGS.ITEM_BIND_ON_PICKUP, 1, 1, 1) end
        if def.unique == true then add(STRINGS.ITEM_UNIQUE_EQUIPPABLE, 1, 1, 1)
        elseif type(def.unique) == "table" then
            add(STRINGS.ITEM_LIMIT_CATEGORY_MULTIPLE:format(def.unique.name, def.unique.count or 1), 1, 1, 1)
        end
        for _, l in ipairs(def.extraLines or {}) do add(l[1], l[2], l[3], l[4]) end
        if def.spell then add(STRINGS.ITEM_SPELL_TRIGGER_ONUSE .. " " .. def.spell.name, 0, 1, 0) end
        return lines
    end

    -- ── the client API ───────────────────────────────────────────────────────────────────────

    for k, v in pairs(STRINGS) do M[k] = v end
    M.NUM_BAG_SLOTS, M.NUM_REAGENTBAG_SLOTS, M.NUM_TOTAL_EQUIPPED_BAG_SLOTS = LAST_BAG, 1, REAGENT_BAG
    M.BACKPACK_CONTAINER, M.CONTAINER_BAG_OFFSET = BACKPACK, CONTAINER_BAG_OFFSET
    M.INVSLOT_FIRST_EQUIPPED, M.INVSLOT_LAST_EQUIPPED = 1, 19
    M.INVSLOT_MAINHAND, M.INVSLOT_OFFHAND = MH, OH
    M.ITEM_INVENTORY_LOCATION_PLAYER, M.ITEM_INVENTORY_LOCATION_BAGS = PLAYER_BIT, BAGS_BIT
    M.ITEM_INVENTORY_LOCATION_BANK, M.ITEM_INVENTORY_BAG_BIT_OFFSET = BANK_BIT, 8
    M.EQUIPMENT_SET_EMPTY_SLOT, M.EQUIPMENT_SET_IGNORED_SLOT, M.EQUIPMENT_SET_ITEM_MISSING = 0, 1, -1
    M.MAX_EQUIPMENT_SETS_PER_PLAYER = 10

    M.GetInventorySlotInfo = function(name)
        local id = SLOT_IDS[name]
        if not id then error("Invalid inventory slot in GetInventorySlotInfo", 2) end
        return id, 136500 + id, false
    end
    -- An inventory id: an equip slot, or a bag's own slot (31-35, ContainerIDToInventoryID).
    local function invAt(unit, id)
        if unit ~= "player" then return nil end
        if type(id) ~= "number" then return nil end
        if id > CONTAINER_BAG_OFFSET and id <= CONTAINER_BAG_OFFSET + REAGENT_BAG then
            local b = G.bags[id - CONTAINER_BAG_OFFSET]
            return b and b.bagInst
        end
        return G.worn[id]
    end
    M.GetInventoryItemLink = function(unit, id) return linkOf(invAt(unit, id)) end
    M.GetInventoryItemID = function(unit, id) local i = invAt(unit, id); return i and i.def.id end
    M.GetInventoryItemTexture = function(unit, id) local i = invAt(unit, id); return i and i.def.icon end
    M.GetInventoryItemQuality = function(unit, id) local i = invAt(unit, id); return i and i.def.quality end
    M.GetInventoryItemDurability = function(id)
        local i = G.worn[id]
        if not (i and i.durability) then return nil end
        return i.durability[1], i.durability[2]
    end
    M.GetInventoryItemCooldown = function(unit, id)
        local i = invAt(unit, id)
        if not i then return 0, 0, 0 end
        local cd = i.cooldown or { 0, 0, 1 }
        return cd[1], cd[2], cd[3]
    end
    M.CanDualWield = function() return G.canDualWield end
    M.CursorHasItem = function() return G.cursor ~= nil end
    M.GetCursorInfo = function()
        if not G.cursor then return nil end
        return "item", G.cursor.inst.def.id, linkOf(G.cursor.inst)
    end
    M.ClearCursor = function() record("ClearCursor"); clearCursor() end
    M.PickupInventoryItem = function(id)
        record("PickupInventoryItem", id)
        if G.cursor then return equipFromCursor(id) end
        return lift({ equip = id })
    end
    M.EquipCursorItem = function(id) record("EquipCursorItem", id); return equipFromCursor(id) end
    M.PutItemInBackpack = function()
        record("PutItemInBackpack")
        if not G.cursor then return end
        local b = G.bags[BACKPACK]
        for slot = 1, b.size do
            if b.slots[slot] == nil then return dropInBag({ bag = BACKPACK, slot = slot }) end
        end
        return fail("ERR_BAG_FULL")
    end
    M.PutItemInBag = function(invID)
        record("PutItemInBag", invID)
        if not G.cursor then return end
        local bag = invID - CONTAINER_BAG_OFFSET
        local b = G.bags[bag]
        if not b then return end
        if not accepts(bag, G.cursor.inst) then return fail("ERR_ITEM_DOESNT_GO_INTO_BAG") end
        for slot = 1, b.size do
            if b.slots[slot] == nil then return dropInBag({ bag = bag, slot = slot }) end
        end
        return fail("ERR_BAG_FULL")
    end
    M.GetInventoryItemsForSlot = function(slotID, out)
        out = out or {}
        for bag = BACKPACK, REAGENT_BAG do
            local b = readable(bag)
            for slot = 1, (b and b.size or 0) do
                local i = b.slots[slot]
                if i and fits(i, slotID) then
                    out[PLAYER_BIT + BAGS_BIT + bag * 256 + slot] = i.def.id
                end
            end
        end
        return out
    end

    local Container = {}
    M.C_Container = Container
    function Container.GetContainerNumSlots(bag) local b = readable(bag); return b and b.size or 0 end
    function Container.GetContainerNumFreeSlots(bag)
        local b = readable(bag)
        if not b then return 0, 0 end
        return G:freeSlots(bag), b.family or 0
    end
    function Container.GetContainerItemLink(bag, slot)
        local b = readable(bag)
        return linkOf(b and b.slots[slot])
    end
    function Container.GetContainerItemID(bag, slot)
        local b = readable(bag)
        local i = b and b.slots[slot]
        return i and i.def.id
    end
    function Container.GetContainerItemInfo(bag, slot)
        local b = readable(bag)
        local i = b and b.slots[slot]
        if not i then return nil end
        return { iconFileID = i.def.icon, stackCount = i.count, isLocked = i.locked, quality = i.def.quality,
                 isReadable = false, hasLoot = false, hyperlink = linkOf(i), isFiltered = false,
                 hasNoValue = false, itemID = i.def.id, isBound = i.bound }
    end
    function Container.GetContainerItemCooldown(bag, slot)
        local b = readable(bag)
        local i = b and b.slots[slot]
        local cd = i and i.cooldown or { 0, 0, 1 }
        return cd[1], cd[2], cd[3]
    end
    function Container.GetBagName(bag)
        if bag == BACKPACK then return "Backpack" end
        local b = G.bags[bag]
        return b and b.bagInst and b.bagInst.def.name
    end
    function Container.ContainerIDToInventoryID(bag)
        if type(bag) == "number" and bag >= 1 and bag <= REAGENT_BAG then return CONTAINER_BAG_OFFSET + bag end
        return nil
    end
    function Container.PickupContainerItem(bag, slot)
        record("PickupContainerItem", bag, slot)
        if not readable(bag) then return end
        if G.cursor then
            local b = G.bags[bag]
            if slot < 1 or slot > b.size then return end
            return dropInBag({ bag = bag, slot = slot })
        end
        return lift({ bag = bag, slot = slot })
    end
    -- Right-click: with the bank open it moves between bank and bags; otherwise it equips gear.
    function Container.UseContainerItem(bag, slot)
        record("UseContainerItem", bag, slot)
        local b = readable(bag)
        local inst = b and b.slots[slot]
        if not inst or G.cursor then return end
        if G.bankOpen then
            local dest = freeSlot(inst, not isBankBag(bag))
            if not dest then return fail(isBankBag(bag) and "ERR_INV_FULL" or "ERR_BAG_FULL") end
            lift({ bag = bag, slot = slot })
            return dropInBag(dest)
        end
        local cands = FITS[inst.def.invType]
        if not cands then return end
        local target = cands[1]
        for _, s in ipairs(cands) do
            if G.worn[s] == nil and fits(inst, s) then target = s; break end
        end
        lift({ bag = bag, slot = slot })
        local ok = equipFromCursor(target)
        if not ok then clearCursor() end
        return ok
    end
    M.PickupContainerItem, M.UseContainerItem = Container.PickupContainerItem, Container.UseContainerItem

    -- Bank tabs (Enum.BagIndex 6-16) the character has bought.
    M.C_Bank = {
        FetchPurchasedBankTabIDs = function(bankType)
            local out = {}
            local first, last = BANK_FIRST, BANK_LAST
            if bankType == 2 then first, last = ACCOUNT_FIRST, ACCOUNT_LAST end
            for tab = first, last do if G.bags[tab] then out[#out + 1] = tab end end
            return out
        end,
    }

    -- ItemLocation: the client's mixin, as plain tables the C_Item calls below understand.
    local function makeLoc(fields)
        fields.__mockLoc = true
        function fields:IsBagAndSlot() return self.bag ~= nil end
        function fields:IsEquipmentSlot() return self.equipSlot ~= nil end
        function fields:GetBagAndSlot() return self.bag, self.slot end
        function fields:GetEquipmentSlot() return self.equipSlot end
        function fields:IsValid() return instAtLocation(self) ~= nil end
        function fields:Clear() self.bag, self.slot, self.equipSlot = nil, nil, nil end
        return fields
    end
    M.ItemLocation = {
        CreateFromBagAndSlot = function(_, bag, slot) return makeLoc({ bag = bag, slot = slot }) end,
        CreateFromEquipmentSlot = function(_, slotID) return makeLoc({ equipSlot = slotID }) end,
        CreateEmpty = function() return makeLoc({}) end,
    }

    local Item = {}
    M.C_Item = Item
    function Item.GetItemInfo(item)
        local def = defFor(item)
        if not def then return nil end
        if G.pending[def.id] then return nil end
        local link = def.link
        if type(item) == "string" and item:find("|H", 1, true) then link = item end
        return def.name, link, def.quality, def.baseLevel, def.minLevel, CLASS_NAMES[def.classID] or "",
               "", 1, def.invType, def.icon, 0, def.classID, def.subclassID, def.bindType, 10, nil, false
    end
    function Item.GetItemInfoInstant(item)
        local def = defFor(item)
        if not def then return nil end
        return def.id, CLASS_NAMES[def.classID] or "", "", def.invType, def.icon, def.classID, def.subclassID
    end
    function Item.GetDetailedItemLevelInfo(item)
        local def = defFor(item)
        if not def then return nil end
        return def.level, false, def.baseLevel
    end
    function Item.GetItemStats(link)
        local def = defFor(link)
        if not def then return nil end
        local out = {}
        for k, v in pairs(def.stats or {}) do out[k] = v end
        return out
    end
    function Item.GetItemSpell(item)
        local def = defFor(item)
        if not (def and def.spell) then return nil end
        return def.spell.name, def.spell.id
    end
    function Item.GetItemUniquenessByID(id)
        local def = defFor(id)
        if not def then return nil end
        if def.unique == true then return true, nil, nil, nil end
        if type(def.unique) == "table" then return true, def.unique.name, def.unique.count, def.unique.id end
        return false, nil, nil, nil
    end
    function Item.GetItemFamily(item)
        local def = defFor(item)
        if not def then return nil end
        return def.bagFamily or def.family or 0
    end
    function Item.GetItemNameByID(id) local def = defFor(id); return def and def.name end
    function Item.GetItemQualityByID(id) local def = defFor(id); return def and def.quality end
    function Item.GetItemIconByID(id) local def = defFor(id); return def and def.icon end
    function Item.IsItemDataCachedByID(id) local def = defFor(id); return def ~= nil and not G.pending[def.id] end
    function Item.RequestLoadItemDataByID(id) record("RequestLoadItemDataByID", id) end
    function Item.DoesItemExist(loc) return instAtLocation(loc) ~= nil end
    function Item.GetItemLink(loc) return linkOf(instAtLocation(loc)) end
    function Item.GetItemID(loc) local i = instAtLocation(loc); return i and i.def.id end
    function Item.GetCurrentItemLevel(loc) local i = instAtLocation(loc); return i and i.def.level end
    function Item.IsBound(loc) local i = instAtLocation(loc); return i ~= nil and i.bound == true end
    function Item.IsBoundToAccountUntilEquip(loc)
        local i = instAtLocation(loc)
        return i ~= nil and i.warbound == true
    end
    function Item.IsLocked(loc) local i = instAtLocation(loc); return i ~= nil and i.locked end

    M.C_PlayerInfo = M.C_PlayerInfo or {}
    M.C_PlayerInfo.CanUseItem = function(id)
        local def = defFor(id)
        return def ~= nil and not def.unusable
    end
    M.C_ItemUpgrade = {
        CanUpgradeItem = function(loc)
            local i = instAtLocation(loc)
            return i ~= nil and (i.def.upType or 0) > 0
        end,
    }
    M.C_AzeriteEmpoweredItem = {
        IsAzeriteEmpoweredItemByID = function(id) local def = defFor(id); return def ~= nil and def.azerite ~= nil end,
        IsAzeriteEmpoweredItem = function(loc)
            local i = instAtLocation(loc)
            return i ~= nil and i.def.azerite ~= nil
        end,
        GetAllTierInfo = function(loc)
            local i = instAtLocation(loc)
            local tiers = {}
            for n, p in ipairs(i and i.def.azerite or {}) do tiers[n] = { azeritePowerIDs = { p }, unlockLevel = n } end
            return tiers
        end,
        IsPowerSelected = function(loc, powerID)
            local i = instAtLocation(loc)
            for _, p in ipairs(i and i.def.azerite or {}) do if p == powerID then return true end end
            return false
        end,
    }

    -- The tooltip data the client builds for an item (C_TooltipInfo), from :tooltipLines.
    local function tipData(inst)
        if not inst then return nil end
        return { type = 0, id = inst.def.id, hyperlink = linkOf(inst), lines = G:tooltipLines(inst) }
    end
    M.C_TooltipInfo = M.C_TooltipInfo or {}
    M.C_TooltipInfo.GetBagItem = function(bag, slot)
        local b = readable(bag)
        return tipData(b and b.slots[slot])
    end
    M.C_TooltipInfo.GetInventoryItem = function(unit, id) return tipData(invAt(unit, id)) end
    M.C_TooltipInfo.GetHyperlink = function(link)
        local def = defFor(link)
        if not def then return nil end
        return { type = 0, id = def.id, hyperlink = link, lines = G:tooltipLines(def) }
    end

    deps.sets.install(M, G, {
        record = record, queue = queue, where = where, fits = fits, lift = lift,
        equipFromCursor = equipFromCursor, freeSlot = freeSlot, dropInBag = dropInBag,
        clearCursor = clearCursor,
    }, EQUIP_IDS)
    return G
end

return Gear
