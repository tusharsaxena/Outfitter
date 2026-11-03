-- tests/test_api.lua — P4.25 (design §5.16, H3): modules/Api.lua's public surface,
-- _G.OutfitterReborn.API.v1, and the global allow-list that replaces the legacy load suite's leak
-- check (design §9.4: the old `Outfitter_*` subset is inverted into "none of them exists").
--
-- The Stack, Outfits, Inventory and Equip are the real modules, and the items move for real in
-- tests/mock_gear.lua. NS.Dock lands in P4.19: the Stack reads NS.Dock.IsShown() on every wear, so a
-- case that wears installs a recorded fake for it (design §12, the fake rule).

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local MEMBERS = {
    "WearOutfit", "RemoveOutfit", "FindOutfitByName", "GetCurrentOutfitInfo", "GetOutfitsUsingItem",
    "RegisterOutfitEvent", "UnregisterOutfitEvent",
}

-- A fresh instance at t = 100 on a gear scenario, the engine resumed and the first scan settled, the
-- window (the Dock fake) closed. Answers NS, the mocks and API.v1 as the global publishes it.
local function scene(scenario)
    local inst = T.load({ mutate = function(M) M.__gear:load(scenario or "geared") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    M.__fireTimers()
    T.fake(NS, "Dock", { IsShown = function() return false end, Suspend = true, Resume = true })
    local root = M._G.OutfitterReborn
    return NS, M, root and root.API and root.API.v1
end

-- The session's first LoadPass (seed, repair, stack, binder): nothing is dispatched before it (INV §6.4).
local function firstPass(NS)
    NS.Outfits.LoadPass()
    return NS
end

local function snapOf(NS, info) return NS.ItemInfo.Snapshot(info) end

-- Every error the client's handler would have shown, in order.
local function catchErrors(M)
    local errs = {}
    M.geterrorhandler = function() return function(e) errs[#errs + 1] = tostring(e) end end
    return errs
end

-- ── the surface ───────────────────────────────────────────────────────────────────────────────

test("api: _G.OutfitterReborn.API.v1 carries exactly the §5.16 members, each a function", function()
    local _, _, v1 = scene()
    assertEqual(type(v1), "table", "API.v1")
    local want = {}
    for _, k in ipairs(MEMBERS) do
        want[k] = true
        assertEqual(type(v1[k]), "function", k)
    end
    -- red under: publish an extra member (a RegisterStatCategory or a FindOutfitByStatID, O42).
    for k in pairs(v1) do assertTrue(want[k], "API.v1." .. tostring(k) .. " is not a §5.16 member") end
end)

test("api: no Outfitter global, no Outfitter_* shim and no OutfitterItemList_* function (H3)", function()
    local _, M = scene()
    -- red under: alias the legacy names, e.g. `Outfitter_WearOutfit = API.WearOutfit`.
    for _, k in ipairs({ "Outfitter", "Outfitter_WearOutfit", "Outfitter_FindOutfitByName",
                         "Outfitter_RegisterOutfitEvent", "Outfitter_GetCurrentOutfitInfo",
                         "Outfitter_GetOutfitsUsingItem", "Outfitter_GenerateSmartOutfit",
                         "OutfitterItemList_GetEquippableItems", "OutfitterAPI", "gOutfitter_Settings" }) do
        assertNil(rawget(_G, k), "_G." .. k)
        assertNil(rawget(M, k), "mock " .. k)
    end
end)

-- ── find ──────────────────────────────────────────────────────────────────────────────────────

test("api: FindOutfitByName is case-insensitive and answers a copy { id, name, category }", function()
    local NS, _, v1 = scene()
    local id = NS.Outfits.Create("Fishing Gear", { HeadSlot = { id = 0 } })
    -- red under: FindOutfitByName comparing names case-sensitively.
    local found = v1.FindOutfitByName("fishing GEAR")
    assertEqual(type(found), "table")
    assertEqual(found.id, id); assertEqual(found.name, "Fishing Gear"); assertEqual(found.category, "Accessory")
    -- red under: answering the stored record itself (a caller's write reaches the store).
    found.name = "Changed"
    found.items = {}
    assertEqual(NS.Outfits.Get(id).name, "Fishing Gear", "the store is untouched by a write to the answer")
    assertTrue(NS.Outfits.Get(id).items ~= found.items)
    local n = 0
    for _ in pairs(v1.FindOutfitByName("Fishing Gear")) do n = n + 1 end
    assertEqual(n, 3, "id, name and category only: no items, no trigger")
    assertNil(v1.FindOutfitByName("Nope"))
    assertNil(v1.FindOutfitByName(nil))
    assertNil(v1.FindOutfitByName(42))
end)

test("api: every member answers its empty value before the saved data exists", function()
    local inst = T.load({ init = false })
    local v1 = inst.mocks._G.OutfitterReborn.API.v1
    -- red under: reaching NS.db.char unguarded (a third-party addon calling at its own load raises).
    assertNil(v1.FindOutfitByName("x"))
    assertFalse(v1.WearOutfit("x"))
    assertFalse(v1.RemoveOutfit("x"))
    assertEqual(v1.GetCurrentOutfitInfo(), "")
    assertEqual(#v1.GetOutfitsUsingItem("|Hitem:1|h"), 0)
end)

-- ── wear and remove ───────────────────────────────────────────────────────────────────────────

test("api: WearOutfit and RemoveOutfit find by name and go through the Stack with hw = false", function()
    local NS, _, v1 = scene()
    local id = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    local St, seen = NS.Stack, {}
    local wear, remove = St.Wear, St.Remove
    St.Wear = function(i, opts) seen[#seen + 1] = { "Wear", i, opts }; return wear(i, opts) end
    St.Remove = function(i, opts) seen[#seen + 1] = { "Remove", i, opts }; return remove(i, opts) end
    assertTrue(v1.WearOutfit("hat"))
    assertTrue(St.IsWorn(id))
    assertEqual(seen[1][2], id)
    -- red under: pass hw = true (the API is no hardware event: it must not change the title).
    assertEqual(type(seen[1][3]), "table"); assertEqual(seen[1][3].hw, false)
    assertNil(seen[1][3].byTrigger)
    assertTrue(v1.RemoveOutfit("HAT"))
    assertFalse(St.IsWorn(id))
    assertEqual(seen[2][1], "Remove"); assertEqual(seen[2][3].hw, false)
    St.Wear, St.Remove = wear, remove
end)

test("api: an unknown name wears nothing, and a remove of an outfit not worn answers false", function()
    local NS, _, v1 = scene()
    NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    local stack = T.fake(NS, "Stack", { Wear = function() return true end, Remove = function() return false end })
    -- red under: calling the Stack with a nil id for a name that matches nothing.
    assertFalse(v1.WearOutfit("Cloak"))
    assertFalse(v1.RemoveOutfit("Cloak"))
    assertEqual(#stack.__calls, 0)
    assertFalse(v1.RemoveOutfit("Hat"), "the Stack's own false comes back")
    assertFalse(v1.WearOutfit(nil))
end)

test("api: while the addon is stood down WearOutfit and RemoveOutfit refuse and touch nothing", function()
    local NS, _, v1 = scene()
    NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    NS.ApplyEnabled(false)
    assertTrue(NS.IsStoodDown())
    local stack = T.fake(NS, "Stack", { Wear = function() return true end, Remove = function() return true end })
    -- red under: no stand-down check (disabled means not running, design §5.12).
    assertFalse(v1.WearOutfit("Hat"))
    assertFalse(v1.RemoveOutfit("Hat"))
    assertEqual(#stack.__calls, 0)
    assertEqual(v1.FindOutfitByName("hat").name, "Hat", "the reads still answer")
end)

-- ── the current outfit ────────────────────────────────────────────────────────────────────────

test("api: GetCurrentOutfitInfo answers \"\" for nothing worn, the name on top, Custom for a temp", function()
    local NS, _, v1 = scene()
    local id = NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    local name, got = v1.GetCurrentOutfitInfo()
    assertEqual(name, ""); assertNil(got)
    v1.WearOutfit("Hat")
    name, got = v1.GetCurrentOutfitInfo()
    -- red under: answering the id instead of the name.
    assertEqual(name, "Hat"); assertEqual(got, id)
    NS.db.char.stack[#NS.db.char.stack + 1] = { temp = { WristSlot = { id = 0 } } }
    name, got = v1.GetCurrentOutfitInfo()
    assertEqual(name, "Custom"); assertNil(got)
end)

-- ── items ─────────────────────────────────────────────────────────────────────────────────────

test("api: GetOutfitsUsingItem answers { {id, name} } copies; a secret or bad link answers none", function()
    local NS, _, v1 = scene()
    local head = NS.ItemInfo.FromSlot("HeadSlot")
    local a = NS.Outfits.Create("Helm", { HeadSlot = snapOf(NS, head) })
    NS.Outfits.Create("Other", { WristSlot = { id = 0 } })
    local using = v1.GetOutfitsUsingItem(head.link)
    assertEqual(#using, 1)
    -- red under: answering the bare ids O.UsingItem returns.
    assertEqual(type(using[1]), "table")
    assertEqual(using[1].id, a); assertEqual(using[1].name, "Helm")
    using[1].name = "x"
    assertEqual(NS.Outfits.Get(a).name, "Helm")
    -- red under: reading a secret link's text (it must reach no string op, only the Secrets seam).
    assertEqual(#v1.GetOutfitsUsingItem(T.secret(head.link)), 0)
    assertEqual(#v1.GetOutfitsUsingItem("not a link"), 0)
    assertEqual(#v1.GetOutfitsUsingItem(nil), 0)
end)

-- ── events ────────────────────────────────────────────────────────────────────────────────────

test("api: a subscriber hears added, edited, renamed, worn, removed and deleted, as fn(event, id, ...)", function()
    local NS, _, v1 = scene()
    firstPass(NS)
    local heard = {}
    assertTrue(v1.RegisterOutfitEvent(function(event, id, ...)
        heard[#heard + 1] = { event = event, id = id, extra = { ... } }
    end))
    local O = NS.Outfits
    local id = O.Create("Hat", { HeadSlot = { id = 0 } })
    O.SetItem(id, "WristSlot", { id = 0 })
    O.Rename(id, "Cap")
    v1.WearOutfit("Cap")
    v1.RemoveOutfit("Cap")
    -- The binder lands in P4.15 (a parallel task): O.Delete unbinds through a recorded fake.
    local binder = T.fake(NS, "TriggerBinder", { Unbind = true })
    O.Delete(id)
    assertEqual(binder.__count("Unbind"), 1)
    local events = {}
    for _, h in ipairs(heard) do
        events[#events + 1] = h.event
        assertEqual(h.id, id, h.event .. "'s id")
    end
    -- red under: drop one of the six messages from the subscription list.
    assertEqual(table.concat(events, ","),
        "OUTFIT_ADDED,OUTFIT_EDITED,OUTFIT_RENAMED,OUTFIT_WORN,OUTFIT_REMOVED,OUTFIT_DELETED")
    assertEqual(heard[3].extra[1], "Hat"); assertEqual(heard[3].extra[2], "Cap")
    assertEqual(heard[6].extra[1], "Cap", "the deleted outfit's name travels with its id")
    for _, h in ipairs(heard) do
        assertFalse(tostring(h.event):find("Ka0s_", 1, true) ~= nil, "the wire name never leaks")
    end
end)

test("api: nothing is dispatched before the session's first LoadPass (INV §6.4)", function()
    local NS, _, v1 = scene()
    local heard = {}
    assertTrue(v1.RegisterOutfitEvent(function(event) heard[#heard + 1] = event end))
    NS.Outfits.Create("Early", { HeadSlot = { id = 0 } })
    NS.Outfits.LoadPass()
    -- red under: a dispatch with no first-LoadPass gate (the seed's OUTFIT_ADDEDs reach the subscriber).
    assertEqual(#heard, 0, "the load's own sends stay inside the addon")
    NS.Outfits.Create("Late", { HeadSlot = { id = 0 } })
    assertEqual(table.concat(heard, ","), "OUTFIT_ADDED")
end)

test("api: a raising subscriber is isolated, and a return value is never an error", function()
    local NS, M, v1 = scene()
    firstPass(NS)
    local errs = catchErrors(M)
    local order = {}
    v1.RegisterOutfitEvent(function() order[#order + 1] = "first"; error("boom") end)
    v1.RegisterOutfitEvent(function() order[#order + 1] = "second"; return "a value" end)
    v1.RegisterOutfitEvent(function() order[#order + 1] = "third"; return false, "also a value" end)
    NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    -- red under: call the subscribers bare (the first one's error stops the rest).
    assertEqual(table.concat(order, ","), "first,second,third")
    -- red under: report a returned value as an error (INV §6.4's legacy Fix).
    assertEqual(#errs, 1, "exactly the one raise is reported")
    assertTrue(errs[1]:find("boom", 1, true) ~= nil, errs[1])
    local id2 = NS.Outfits.Create("Cap", { HeadSlot = { id = 0 } })
    assertTrue(NS.Outfits.Get(id2) ~= nil, "the sender was not broken by the raise")
    assertEqual(#errs, 2)
end)

test("api: Unregister stops the calls, a second Register is one subscription, a non-function is refused", function()
    local NS, _, v1 = scene()
    firstPass(NS)
    local n = 0
    local function fn() n = n + 1 end
    assertTrue(v1.RegisterOutfitEvent(fn))
    -- red under: append a duplicate (a second Register would double every call).
    assertTrue(v1.RegisterOutfitEvent(fn))
    NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    assertEqual(n, 1)
    -- red under: an Unregister that does not remove the function.
    assertTrue(v1.UnregisterOutfitEvent(fn))
    NS.Outfits.Create("Cap", { HeadSlot = { id = 0 } })
    assertEqual(n, 1)
    assertFalse(v1.UnregisterOutfitEvent(fn), "not subscribed any more")
    assertFalse(v1.RegisterOutfitEvent("fn"))
    assertFalse(v1.RegisterOutfitEvent(nil))
end)

test("api: a subscriber that unregisters itself mid-dispatch does not skip the next one", function()
    local NS, _, v1 = scene()
    firstPass(NS)
    local order = {}
    local first
    first = function() order[#order + 1] = "first"; v1.UnregisterOutfitEvent(first) end
    v1.RegisterOutfitEvent(first)
    v1.RegisterOutfitEvent(function() order[#order + 1] = "second" end)
    NS.Outfits.Create("Hat", { HeadSlot = { id = 0 } })
    -- red under: walk the live list (the removal shifts "second" into the slot just visited).
    assertEqual(table.concat(order, ","), "first,second")
end)

test("api: a stand-down silences the subscribers and a stand-up brings them back", function()
    local NS, _, v1 = scene()
    firstPass(NS)
    local n = 0
    v1.RegisterOutfitEvent(function() n = n + 1 end)
    NS.ApplyEnabled(false)
    NS.SendBus(NS.MSG.OUTFIT_ADDED, "o99")
    -- red under: a receiver outside the bus record (NS.NewBusTarget), which the stand-down cannot drop.
    assertEqual(n, 0)
    NS.ApplyEnabled(true)
    NS.SendBus(NS.MSG.OUTFIT_ADDED, "o99")
    assertEqual(n, 1)
end)

test("api: without a bus target Register answers false, and the library-absent load still publishes v1", function()
    local inst = T.load()
    local v1 = inst.mocks._G.OutfitterReborn.API.v1
    inst.NS.NewBusTarget = function() return nil end          -- AceEvent absent: the bus hands out nothing
    -- red under: an install that indexes the nil target (RegisterMessage on nil raises).
    assertFalse(v1.RegisterOutfitEvent(function() end), "no bus target, no subscription")
    local bare = T.load({ libFiles = {} })
    local v1b = bare.mocks._G.OutfitterReborn.API.v1
    assertEqual(type(v1b), "table")
    assertEqual(v1b.GetCurrentOutfitInfo(), "")
    assertNil(v1b.FindOutfitByName("x"))
end)

-- ── the global allow-list (H3; the inverted leak check of the legacy load suite) ──────────────

-- Every global whose name carries "outfitter" in any case must be one of these. The harness's own
-- OUTFITTERREBORN_TEST is the runner's, not the addon's.
local EXACT = {
    OutfitterReborn = true, OutfitterRebornDB = true, OutfitterRebornPerfDB = true,
    BINDING_HEADER_OUTFITTERREBORN = true, OUTFITTERREBORN_TEST = true,
}

--- Whether a global named `k` holding `v` is allowed; false for a name this addon may not own.
local function allowed(k, v)
    if EXACT[k] then return true end
    if k:find("^SLASH_") then return true end                       -- AceConsole's slash names
    if k:find("^BINDING_NAME_CLICK OutfitterReborn%w+:LeftButton$") then return true end
    -- the OutfitterReborn* frames, the 14 binding buttons among them: a frame, never a function or data
    if k:find("^OutfitterReborn%u") and type(v) == "table" and type(v.GetObjectType) == "function" then
        return true
    end
    return false
end

--- The names in `tbl` (walked raw) that carry "outfitter" and are not allowed.
local function strays(tbl, out)
    for k, v in next, tbl do
        if type(k) == "string" and k:lower():find("outfitter", 1, true) and not allowed(k, v) then
            out[#out + 1] = k
        end
    end
    return out
end

local function leaks(inst)
    local out = strays(_G, {})
    strays(inst.mocks, out)                -- a named frame is published on the mock
    strays(inst.mocks._G, out)             -- a rawset through the chunk's _G lands on the env table
    table.sort(out)
    return out
end

test("api: the allow-list scan catches a legacy global and passes an allowed one (mutation self-test)", function()
    assertFalse(allowed("Outfitter_WearOutfit", function() end))
    assertFalse(allowed("gOutfitter_Settings", {}))
    assertFalse(allowed("Outfitter", {}))
    assertFalse(allowed("OutfitterFrame", { GetObjectType = function() return "Frame" end }))
    assertFalse(allowed("OutfitterRebornHelper", function() end), "a function under the frame prefix")
    assertFalse(allowed("OUTFITTERREBORN_DELETE_ALL", {}), "a popup lives in StaticPopupDialogs, not _G")
    assertTrue(allowed("OutfitterRebornWearOutfit3", { GetObjectType = function() return "Button" end }))
    assertTrue(allowed("BINDING_NAME_CLICK OutfitterRebornWearOutfit3:LeftButton", "Wear outfit 3"))
    assertTrue(allowed("SLASH_OUTFITTERREBORN1", "/of"))
    local planted = {}
    planted.Outfitter_FindOutfitByName = function() end
    assertEqual(table.concat(strays(planted, {}), ","), "Outfitter_FindOutfitByName")
end)

test("api: after load, init and enable every outfitter-named global is on the allow-list", function()
    local inst = T.load()
    -- red under: add `Outfitter_WearOutfit = API.WearOutfit` (or any other shim) to modules/Api.lua.
    assertEqual(table.concat(leaks(inst), ", "), "")
    local popups = rawget(_G, "StaticPopupDialogs") or inst.mocks.StaticPopupDialogs or {}
    for k in pairs(popups) do
        if type(k) == "string" and k:lower():find("outfitter", 1, true) then
            assertTrue(k:find("^OUTFITTERREBORN_") ~= nil, "popup " .. k)
        end
    end
end)

--- Lua source with its comments removed: long comments first, then line comments.
local function stripLuaComments(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (text:gsub("%-%-[^\n]*", ""))
end

test("api: no shipped file names an Outfitter_*, gOutfitter_* or OutfitterItemList_* identifier in code", function()
    local hits = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") then
            local f = assert(io.open(T.root .. "/" .. rel, "rb"))
            local code = stripLuaComments(f:read("*a"))
            f:close()
            -- red under: a lazily-defined shim the load-time scan cannot see (inside a function body).
            for _, pat in ipairs({ "%f[%w_]g?Outfitter_%w", "%f[%w_]OutfitterItemList_", "%f[%w_]OutfitterAPI%f[^%w_]" }) do
                if code:find(pat) then hits[#hits + 1] = rel .. " (" .. pat .. ")" end
            end
        end
    end
    assertEqual(table.concat(hits, "; "), "")
end)
