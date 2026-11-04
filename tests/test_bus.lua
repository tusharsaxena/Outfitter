-- tests/test_bus.lua — the bus seam (design §2.3, BP §6.11; P3 C7 part): NS.MSG is the full catalog
-- with Ka0s_OutfitterReborn_<Pascal of the key> wire names, each unique and strict; the wire literals
-- live in core/Bus.lua only; exactly one file sends each key, and it is the file §2.3 names; and the
-- receiver record drops and replays on both arms; and every pseudo event a trigger consumes has a
-- producer, and the reverse (P4.15). "At most one sender" tightened to "exactly one" at P4.27. The
-- follow-up dropped STATS_CHANGED and LEGACY_DETECTED: sent, but no module or API subscriber heard them.

local T = _G.OUTFITTERREBORN_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertErrorMatches =
    T.test, T.assertEqual, T.assertTrue, T.assertErrorMatches

-- Design §2.3: every key and the one file that sends it.
local SENDERS = {
    SETTINGS_CHANGED     = "settings/Schema.lua",
    PROFILE_CHANGED      = "core/Database.lua",
    OUTFIT_ADDED         = "modules/Outfits.lua",
    OUTFIT_DELETED       = "modules/Outfits.lua",
    OUTFIT_EDITED        = "modules/Outfits.lua",
    OUTFIT_RENAMED       = "modules/Outfits.lua",
    OUTFIT_WORN          = "modules/OutfitStack.lua",
    OUTFIT_REMOVED       = "modules/OutfitStack.lua",
    SELECTION_CHANGED    = "modules/OutfitStack.lua",
    STACK_CHANGED        = "modules/Equip.lua",
    INVENTORY_CHANGED    = "modules/Inventory.lua",
    SWAP_COMPLETE        = "modules/OutfitStack_Watch.lua",
    EM_SYNCED            = "modules/EquipmentManager.lua",
    OPTIMIZE_STARTED     = "modules/Optimize.lua",
    OPTIMIZE_PROGRESS    = "modules/Optimize.lua",
    OPTIMIZE_DONE        = "modules/Optimize.lua",
    PLAYER_STATE_CHANGED = "modules/PlayerState.lua",
    STATE_CHANGED        = "modules/States.lua",
    AURAS_SCANNED        = "modules/States.lua",
    TOOLTIP_SHOWN        = "modules/States.lua",
    TOOLTIP_HIDDEN       = "modules/States.lua",
    TRIGGERS_REBOUND     = "modules/Triggers_Binder.lua",
    PREVIEW_CHANGED      = "modules/Preview.lua",
}
local KEY_COUNT = 23

local PREFIX = "Ka0s_OutfitterReborn_"

local function pascal(key)
    return (key:lower():gsub("^%l", string.upper):gsub("_(%l)", string.upper))
end

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "r"))
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
end

-- The authored Lua the client loads, as { rel = text }.
local function authoredSources()
    local out = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") then out[rel] = readFile(rel) end
    end
    return out
end

-- Every `SendBus(NS.MSG.KEY` call site in `sources`, checked against `senders`: answers a sorted
-- list of faults (a key sent from two files, or from a file other than its declared sender, or a
-- key the catalog does not declare, or a declared key no file sends). A bare `:SendMessage(` outside
-- core/Bus.lua is a fault too: every message leaves through NS.SendBus. Comments are stripped first,
-- so prose can name a call.
local function senderFaults(sources, senders)
    local faults, seen = {}, {}
    local files = {}
    for rel in pairs(sources) do files[#files + 1] = rel end
    table.sort(files)
    for _, rel in ipairs(files) do
        local text = sources[rel]:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
        for key in text:gmatch("SendBus%(%s*NS%.MSG%.([%u_]+)") do
            local want = senders[key]
            if not want then
                faults[#faults + 1] = rel .. " sends undeclared " .. key
            elseif want ~= rel then
                faults[#faults + 1] = rel .. " sends " .. key .. ", which belongs to " .. want
            end
            seen[key] = seen[key] or {}
            seen[key][rel] = true
        end
        if rel ~= "core/Bus.lua" and text:find("[:.]SendMessage%s*%(") then
            faults[#faults + 1] = rel .. " calls SendMessage directly"
        end
    end
    for key, from in pairs(seen) do
        local n = 0
        for _ in pairs(from) do n = n + 1 end
        if n > 1 then faults[#faults + 1] = key .. " has " .. n .. " sending files" end
    end
    for key in pairs(senders) do
        if not seen[key] then faults[#faults + 1] = key .. " has no sender" end
    end
    table.sort(faults)
    return faults
end

-- ── the catalog ───────────────────────────────────────────────────────────────────────────────

test("bus: NS.MSG is the full §2.3 catalog, wire names Ka0s_OutfitterReborn_<Pascal of the key>", function()
    local n, owner = 0, {}
    for key, wire in pairs(NS.MSG) do
        n = n + 1
        assertTrue(SENDERS[key] ~= nil, "undeclared in §2.3: " .. tostring(key))
        assertEqual(wire, PREFIX .. pascal(key), key)
        assertTrue(owner[wire] == nil, wire .. " is declared by " .. tostring(owner[wire]) .. " and " .. key)
        owner[wire] = key
    end
    assertEqual(n, KEY_COUNT)
    for key in pairs(SENDERS) do assertEqual(type(NS.MSG[key]), "string", key .. " is declared") end
    assertEqual(pascal("EM_SYNCED"), "EmSynced", "the Pascal rule itself")
end)

test("bus: the live catalog is LibKa0s-Bus's strict copy, a typo raises for reader and writer", function()
    local lib = T.mocks.LibStub("LibKa0s-Bus-1.0", true)
    assertTrue(lib ~= nil, "the vendored Bus major registered")
    assertEqual(NS.BusLib, lib)
    assertErrorMatches(function() return NS.MSG.OUTFIT_WORNN end, "OUTFIT_WORNN")
    T.assertError(function() NS.MSG.NEW_KEY = PREFIX .. "NewKey" end, "the catalog takes no new key")
end)

test("bus: without LibKa0s the catalog is the same plain table", function()
    local inst = T.load({ libFiles = {}, init = false })
    local n = 0
    for key, wire in pairs(inst.NS.MSG) do
        n = n + 1
        assertEqual(wire, NS.MSG[key], key)
    end
    assertEqual(n, KEY_COUNT)
    assertTrue(inst.NS.BusLib ~= T.mocks.LibStub("LibKa0s-Bus-1.0", true), "the stub, not the library")
    assertEqual(inst.NS.MSG.OUTFIT_WORNN, nil, "the stub's table is not strict")
end)

test("bus: every Sender line in core/Bus.lua names the §2.3 file", function()
    local text = readFile("core/Bus.lua")
    local n, sender = 0, nil
    for line in text:gmatch("[^\n]*") do
        local s = line:match("^%s*%-%- Sender: ([%w_/]+%.lua)")
        local key = line:match("^%s*([%u_]+)%s*=%s*\"" .. PREFIX)
        if s then
            sender = s
        elseif key then
            assertEqual(sender, SENDERS[key], key .. "'s Sender line")
            sender, n = nil, n + 1
        end
    end
    assertEqual(n, KEY_COUNT, "one Sender line per key")
end)

-- ── the wire literals and the senders ─────────────────────────────────────────────────────────

test("bus: the Ka0s_OutfitterReborn_ literal appears in core/Bus.lua only", function()
    local count = 0
    for rel, text in pairs(authoredSources()) do
        count = count + 1
        if rel ~= "core/Bus.lua" then
            assertTrue(text:find(PREFIX, 1, true) == nil, rel .. " spells a wire name")
        end
    end
    assertTrue(count > 10, "the scan saw the authored files")
end)

test("bus: exactly one file sends each key, and it is the §2.3 sender", function()
    -- red under: the NS.SendBus in modules/Equip.lua removed (STACK_CHANGED has no sender), or a
    -- NS.SendBus(NS.MSG.STATS_CHANGED) put back in modules/ItemStats.lua (an undeclared key).
    local faults = senderFaults(authoredSources(), SENDERS)
    assertEqual(table.concat(faults, "; "), "")
end)

test("bus: the sender scan catches a second sender, a wrong sender, a typo, a bare send and a silent key", function()
    -- red under: senderFaults returning {} (the scan above would pass with no check at all).
    local faults = senderFaults({
        ["modules/Outfits.lua"]     = "NS.SendBus(NS.MSG.OUTFIT_ADDED, id)\nNS.SendBus( NS.MSG.OUTFIT_WORN, id)",
        ["modules/OutfitStack.lua"] = "NS.SendBus(NS.MSG.OUTFIT_WORN, id, 1)\nNS.SendBus(NS.MSG.NOPE)",
        ["modules/Bar.lua"]         = "NS.addon:SendMessage(NS.MSG.STACK_CHANGED)",
        ["core/Bus.lua"]            = "-- NS.SendBus(NS.MSG.KEY, ...)\naddon:SendMessage(name, ...)",
    }, { OUTFIT_ADDED = SENDERS.OUTFIT_ADDED, OUTFIT_WORN = SENDERS.OUTFIT_WORN,
         STACK_CHANGED = SENDERS.STACK_CHANGED })
    assertEqual(table.concat(faults, "; "), table.concat({
        "OUTFIT_WORN has 2 sending files",
        "STACK_CHANGED has no sender",
        "modules/Bar.lua calls SendMessage directly",
        "modules/OutfitStack.lua sends undeclared NOPE",
        "modules/Outfits.lua sends OUTFIT_WORN, which belongs to modules/OutfitStack.lua",
    }, "; "))
end)

-- ── the pseudo events (P4.15, design §6.7, H14) ───────────────────────────────────────────────

test("bus: every pseudo event a descriptor consumes has a producer, and every produced one a consumer", function()
    -- red under: a descriptor naming a STATE:<id> no producer sets, a PSEUDO key mapped to a message no
    -- file sends, or a state the producers set that no trigger reads.
    local Tr, sources = NS.Triggers, authoredSources()
    local produced = {}
    for _, id in ipairs(NS.States.STATES) do produced["STATE:" .. id] = true end
    for _, z in ipairs(NS.Zones.rows) do produced["STATE:" .. z.id] = true end
    for key, msg in pairs(Tr.PSEUDO) do
        if msg then
            assertTrue(SENDERS[msg] ~= nil, key .. " maps to " .. tostring(msg) .. ", which §2.3 does not declare")
            local text = sources[SENDERS[msg]] or ""
            assertTrue(text:find("SendBus%(%s*NS%.MSG%." .. msg .. "[,%)]") ~= nil,
                SENDERS[msg] .. " never sends " .. msg .. " (" .. key .. ")")
            if key ~= "STATE" then produced[key] = true end
        end
    end
    local consumed = {}
    for _, desc in ipairs(Tr.All()) do
        for _, e in ipairs(desc.events) do
            if Tr.IsPseudo(e) and Tr.PSEUDO[e] ~= false then
                consumed[e] = true
                assertTrue(produced[e] == true, desc.id .. " consumes " .. e .. ", which nothing produces")
            end
        end
    end
    for e in pairs(produced) do assertTrue(consumed[e] == true, e .. " is produced, and no trigger reads it") end
end)

-- ── the receiver record, both arms ────────────────────────────────────────────────────────────

local function exerciseRecord(ns, arm)
    for _, name in ipairs({ "NewBusTarget", "SendBus", "BusStandDown", "BusStandUp" }) do
        assertEqual(type(ns[name]), "function", arm .. ": NS." .. name)
    end
    local heard = {}
    local target = ns.NewBusTarget()
    assertTrue(target ~= nil, arm .. ": a target while AceEvent loads")
    assertTrue(target ~= ns.NewBusTarget(), arm .. ": one target per receiver, never shared")
    target:RegisterMessage(ns.MSG.OUTFIT_WORN, function(_, id, layer) heard[#heard + 1] = id .. ":" .. layer end)

    ns.SendBus(ns.MSG.OUTFIT_WORN, 7, "main")
    assertEqual(table.concat(heard, ","), "7:main", arm .. ": the payload reaches the receiver")

    assertTrue(ns.BusStandDown() >= 1, arm .. ": the stand-down counts the recorded entry")
    ns.SendBus(ns.MSG.OUTFIT_WORN, 8, "main")
    assertEqual(#heard, 1, arm .. ": a stood-down receiver hears nothing")

    local replayed, rejected = ns.BusStandUp()
    assertTrue(replayed >= 1, arm .. ": the stand-up replays the record")
    assertEqual(type(rejected), "table", arm .. ": rejected is an array")
    assertEqual(#rejected, 0, arm .. ": nothing rejected")
    ns.SendBus(ns.MSG.OUTFIT_WORN, 9, "main")
    assertEqual(table.concat(heard, ","), "7:main,9:main", arm .. ": the replayed receiver hears again")
    target:UnregisterAllMessages()
end

test("bus: the live arm's record sends, drops at stand-down and replays at stand-up", function()
    exerciseRecord(T.load().NS, "live")
end)

test("bus: the library-absent arm's record does the same", function()
    exerciseRecord(T.load({ libFiles = {} }).NS, "absent")
end)

test("bus: a stand-up is refused while the latch says the addon is down", function()
    for _, opts in ipairs({ {}, { libFiles = {} } }) do
        local ns = T.load(opts).NS
        local down = true
        ns.IsStoodDown = function() return down end
        local heard = 0
        local target = ns.NewBusTarget()
        target:RegisterMessage(ns.MSG.STACK_CHANGED, function() heard = heard + 1 end)
        ns.BusStandDown()
        assertEqual((ns.BusStandUp()), 0, "refused while the latch is down")
        ns.SendBus(ns.MSG.STACK_CHANGED)
        assertEqual(heard, 0)
        down = false
        assertTrue(ns.BusStandUp() >= 1)
        ns.SendBus(ns.MSG.STACK_CHANGED)
        assertEqual(heard, 1)
    end
end)

test("bus: NS.SendBus before NS.addon exists is a silent no-op", function()
    local ns = T.load({ init = false }).NS
    local saved = ns.addon
    ns.addon = nil
    local ok = pcall(ns.SendBus, ns.MSG.STACK_CHANGED)
    ns.addon = saved
    assertTrue(ok, "no addon object, no send, no raise")
end)
