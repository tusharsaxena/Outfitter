-- tests/test_itemlink.lua — P4.4's two modules (design §5.2, §5.3): modules/ItemInfo.lua's link parse,
-- item records, the lazy bind / unique / usable reads, identity and comparison, and the iteminfo
-- lines (B11, B12, B14); and modules/PlayerState.lua, the one owner of the combat, dead, cast and
-- spec flags. The catalog (design §9.3) names this one suite for the task, so PlayerState's cases
-- live here too, after the ItemInfo ones.
--
-- Equip lands in P4.8: PlayerState's calls into it run against a recorded fake (design §12, the fake
-- rule), and test_equip_bracket pins the real behavior.

local T = _G.OUTFITTERREBORN_TEST
-- A unit instance: the login without the resume walk, so the module under test is the one this
-- suite stands up (tests/unit_load.lua).
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local Items = T.fixtures.items
local DB = Items.db

-- A fresh instance with a gear scenario loaded before the addon's files run.
local function gearInstance(scenario, mutate)
    return unitLoad({ mutate = function(M)
        if scenario then M.__gear:load(scenario) end
        if mutate then mutate(M) end
    end })
end

local function II() return T.NS.ItemInfo end

-- ── ParseLink ─────────────────────────────────────────────────────────────────────────────────

test("itemlink: NS.ItemInfo and NS.PlayerState are published", function()
    assertEqual(type(T.NS.ItemInfo), "table", "NS.ItemInfo")
    assertEqual(type(T.NS.ItemInfo.ParseLink), "function", "ParseLink")
    assertEqual(type(T.NS.PlayerState), "table", "NS.PlayerState")
end)

test("itemlink: a full link reads every captured field at its position, against the legacy codes", function()
    -- The legacy parse of the same two links (tests/fixtures/legacy/matching.lua), position by
    -- position: 2 enchant, 3-6 gems, 7 suffix, 8 unique id, 11 upgrade type, 12 difficulty.
    for _, case in ipairs(T.legacy.matching.links) do
        local f, name = II().ParseLink(case.link)
        if case.codes then
            local c = case.codes
            assertEqual(f.id, c[1], case.link .. " id")
            assertEqual(f.enchant, c[2], "enchant")
            assertEqual(f.gems, ("%d:%d:%d:%d"):format(c[3], c[4], c[5], c[6]), "gems")
            assertEqual(f.suffix, c[7], "suffix")
            assertEqual(f.uid, c[8], "uid")
            assertEqual(f.upType, c[11], "upType")
            assertEqual(f.diff, c[12], "diff")
            assertEqual(name, case.name, "name")
        else
            -- red under: ParseLink answering a table for a link that carries no item.
            assertNil(f, case.link .. " is no item link")
        end
    end
end)

test("itemlink: fields 9 (LinkLevel) and 10 (SpecID) are not captured (Q9)", function()
    local f = II().ParseLink(T.legacy.matching.links[2].link)   -- field 9 = 80, field 10 = 73
    -- red under: a FIELD_POS entry for position 9 or 10 (any key whose value is 80 or 73).
    for k, v in pairs(f) do
        assertTrue(v ~= 80 and v ~= 73, "field " .. k .. " carries LinkLevel or SpecID")
    end
    assertNil(f.linkLevel)
    assertNil(f.specID)
end)

test("itemlink: every bonus id is kept, in link order, and the modifier pairs after them (B12)", function()
    -- legacy: "3:10353:1520" with UpgradeID read from field 16 (two bonus ids, the third lost; INV §19
    -- B12, OutfitterInventory.lua:356-371); fixed: every bonus id and every modifier pair.
    local wrist = II().ParseLink(DB.wrist_plate.link)
    -- red under: the legacy two-id capture (only "10353:1520") or a sorted list.
    assertEqual(wrist.bonus, "10353:1520:10255", "all three bonus ids")
    assertEqual(wrist.mods, "28=2734", "the modifier after the bonus list")
    local champ = II().ParseLink(DB.chest_champion.link)
    assertEqual(champ.bonus, "10297:1514")
    -- red under: reading the modifiers from field 14 + n (the count) rather than 15 + n.
    assertEqual(champ.mods, "9=80:28=2462", "two modifier pairs")
    assertEqual(champ.upType, 4)
    assertEqual(champ.diff, 14)
    local plain = II().ParseLink(DB.ring_plain_a.link)
    assertEqual(plain.bonus, "", "no bonus ids reads empty")
    assertEqual(plain.mods, "", "no modifiers reads empty")
end)

test("itemlink: a short link pads every missing field with 0 and an empty list (B11)", function()
    -- legacy: raises (tonumber(nil) > 0 on the missing bonus count; INV §19 B11, OutfitterInventory.lua
    -- :361); fixed: every missing field reads 0 and the lists read "".
    -- red under: indexing a missing field without a default (the legacy raise on a short link).
    local f, name = II().ParseLink("item:19019")
    assertEqual(f.id, 19019)
    assertEqual(f.enchant, 0)
    assertEqual(f.gems, "0:0:0:0")
    assertEqual(f.suffix, 0)
    assertEqual(f.uid, 0)
    assertEqual(f.upType, 0)
    assertEqual(f.diff, 0)
    assertEqual(f.bonus, "")
    assertEqual(f.mods, "")
    assertNil(name, "a bare itemString has no name")
    local g = II().ParseLink("|cnIQ3:|Hitem:212030:7340|h[Band]|h|r")
    assertEqual(g.enchant, 7340)
    assertEqual(g.gems, "0:0:0:0", "gems past the end read 0")
end)

test("itemlink: a negative field keeps its sign (B11)", function()
    -- legacy: 5, 31 and 7 (the "%d*:" capture drops the minus sign; INV §19 B11, OutfitterInventory.lua
    -- :186); fixed: -5, -31 and -7.
    -- red under: the pattern "(%d*)" (the legacy capture dropped the minus sign).
    local f = II().ParseLink("item:212030:-5:0:0:0:0:-31:-7:80::::0:0")
    assertEqual(f.enchant, -5, "enchant")
    assertEqual(f.suffix, -31, "suffix")
    assertEqual(f.uid, -7, "uid")
    local m = II().ParseLink("item:212030::::::::80:::::1:-29:-4")
    assertEqual(m.mods, "-29=-4", "a signed modifier pair")
end)

test("itemlink: the 12.x |cnIQ color form reads like a classic |cff link", function()
    -- red under: splitFields matching "|cff%x+|Hitem:" (the |cnIQ link reads no fields; diff 0).
    local f, name = II().ParseLink(DB.chest_hero.link)
    assertEqual(f.id, 212020)
    assertEqual(name, "Hauberk of Tracks")
    assertEqual(f.bonus, "10298:1527")
    assertEqual(f.diff, 15)
end)

test("itemlink: a secret, nil, non-string or non-item link parses to nil", function()
    -- red under: ParseLink reading the link before Secrets.PlainString (the trap raises on the match).
    assertNil(II().ParseLink(T.secret(DB.head_plate.link)), "secret")
    assertNil(II().ParseLink(nil), "nil")
    assertNil(II().ParseLink(42), "a number")
    assertNil(II().ParseLink("|cffffffff|Hspell:2645|h[Ghost Wolf]|h|r"), "a spell link")
    assertNil(II().FromLink(T.secret(DB.head_plate.link)), "FromLink of a secret")
end)

-- ── item records ──────────────────────────────────────────────────────────────────────────────

test("itemlink: FromSlot reads the worn item: identity, client info, slot and location", function()
    local inst = gearInstance("geared")
    local info = inst.NS.ItemInfo.FromSlot("HeadSlot")
    assertEqual(info.id, 212001)
    assertEqual(info.name, "Helm of the Test Bench")
    assertEqual(info.quality, 4)
    assertEqual(info.level, 639)
    assertEqual(info.invType, "INVTYPE_HEAD")
    assertEqual(info.slot, "HeadSlot")
    assertEqual(info.bonus, "10353:1520")
    assertEqual(info.link, DB.head_plate.link)
    assertEqual(info.loc.slotID, 1, "an equipped location")
    -- red under: build() answering a record for a nil link (an empty slot reads as an item).
    local none = gearInstance("naked").NS.ItemInfo.FromSlot("HeadSlot")
    assertNil(none, "an empty slot")
end)

test("itemlink: FromBag reads a bag item with its location and bag family", function()
    local inst = gearInstance("geared")
    local info = inst.NS.ItemInfo.FromBag(0, 5)
    assertEqual(info.id, 212020)
    assertEqual(info.bonus, "10298:1527")
    assertEqual(info.mods, "9=80:28=2463")
    assertEqual(info.loc.bag, 0)
    assertEqual(info.loc.slot, 5)
    assertEqual(info.bagType, 0, "the item's own bag-family bits")
    -- red under: fill() setting meta for every slotted type (the chest gains a meta slot).
    assertEqual(info.meta, nil, "a chest has no meta slot")
    local sword = inst.NS.ItemInfo.FromBag(0, 1)
    assertEqual(sword.slot, "MainHandSlot")
    assertEqual(sword.meta, "TwoHandSlot")
    -- red under: build() answering a record for a nil link.
    assertNil(inst.NS.ItemInfo.FromBag(0, 16), "an empty bag slot")
end)

test("itemlink: a secret worn or carried item reads as no item (Q12)", function()
    local inst = gearInstance("secret_slots")
    -- red under: build() answering a record when the link is refused (the secret slot reads as an item).
    assertNil(inst.NS.ItemInfo.FromSlot("HeadSlot"), "secret worn")
    assertNil(inst.NS.ItemInfo.FromBag(0, 1), "secret carried")
    assertEqual(inst.NS.ItemInfo.FromBag(0, 2).id, 212030, "the plain neighbor still reads")
end)

test("itemlink: the azerite powers are sorted and joined; none reads empty", function()
    local inst = gearInstance("upgrade_tracks")
    -- red under: the powers kept in link order (560:13:30).
    assertEqual(inst.NS.ItemInfo.FromBag(0, 2).azerite, "13:30:560")
    assertEqual(inst.NS.ItemInfo.FromBag(0, 1).azerite, "")
    assertEqual(inst.NS.ItemInfo.FromLink(DB.chest_azerite.link).azerite, "", "a link has no location")
end)

test("itemlink: CORRECTIONS override the item's fields, and an emptied invType has no slot", function()
    local inst = gearInstance("geared")
    local C = inst.NS.ItemData.CORRECTIONS
    C[212001] = { invType = "", type = "Trade Goods" }
    local info = inst.NS.ItemInfo.FromSlot("HeadSlot")
    C[212001] = nil
    -- red under: applying the correction after the slot lookup (slot stays HeadSlot).
    assertEqual(info.invType, "")
    assertEqual(info.type, "Trade Goods")
    assertNil(info.slot, "a corrected-away inventory type")
end)

test("itemlink: Snapshot copies only the ItemRecord keys, and EMPTY is the one empty marker", function()
    local inst = gearInstance("geared")
    local NSi = inst.NS
    local info = NSi.ItemInfo.FromSlot("ChestSlot")
    info.score = 12
    local rec = NSi.ItemInfo.Snapshot(info)
    local want = { id = true, suffix = true, enchant = true, gems = true, uid = true, upType = true, diff = true,
                   bonus = true, mods = true, azerite = true, link = true, name = true, invType = true,
                   quality = true, level = true }
    -- red under: Snapshot copying `loc`, `slot` or a score cache (live objects reaching the store, B15).
    for k in pairs(rec) do assertTrue(want[k], "Snapshot carried " .. k) end
    assertEqual(rec.id, 212005)
    assertEqual(rec.enchant, 7334)
    assertEqual(rec.link, DB.chest_plate.link)
    assertEqual(NSi.ItemInfo.EMPTY.id, 0)
    local n = 0
    for _ in pairs(NSi.ItemInfo.EMPTY) do n = n + 1 end
    assertEqual(n, 1, "EMPTY is { id = 0 } and nothing else")
end)

-- ── lazy reads: bind, uniqueness, usability ───────────────────────────────────────────────────

test("itemlink: Bind answers bound / boe / warbound / none from the client's location reads", function()
    local inst = gearInstance("geared")
    local I = inst.NS.ItemInfo
    -- red under: readBind testing bindType before IsBound (the worn BoP and the hearthstone read "none").
    assertEqual(I.Bind(I.FromSlot("HeadSlot")), "bound", "worn")
    assertEqual(I.Bind(I.FromBag(0, 3)), "boe", "boe_legs in the backpack")
    assertEqual(I.Bind(I.FromBag(1, 1)), "warbound", "warbound_cloak")
    assertEqual(I.Bind(I.FromBag(0, 4)), "bound", "the hearthstone")
end)

test("itemlink: without the client's bind reads, Bind falls back to the tooltip lines", function()
    local inst = gearInstance("geared", function(M)
        M.C_Item.IsBound, M.C_Item.IsBoundToAccountUntilEquip = nil, nil
    end)
    local I = inst.NS.ItemInfo
    -- red under: dropping the tooltip fallback (every item reads "none").
    assertEqual(I.Bind(I.FromBag(0, 3)), "boe")
    assertEqual(I.Bind(I.FromBag(1, 1)), "warbound")
    assertEqual(I.Bind(I.FromSlot("HeadSlot")), "bound", "the Soulbound line")
    assertEqual(I.Bind(I.FromLink(DB.boe_legs.link)), "boe", "a bare link reads its own tooltip")
end)

test("itemlink: Bind is lazy, asked once per info", function()
    local inst = gearInstance("geared")
    local I, M = inst.NS.ItemInfo, inst.mocks
    local asked, real = 0, M.C_Item.IsBound
    M.C_Item.IsBound = function(...) asked = asked + 1; return real(...) end
    local info = I.FromBag(0, 3)
    assertEqual(asked, 0, "FromBag asked about binding up front")
    I.Bind(info)
    I.Bind(info)
    -- red under: II.Bind calling readBind on every ask (no info.bind cache).
    assertEqual(asked, 1, "the second Bind asked again")
end)

test("itemlink: an uncached item's unknown bindType is no \"not BoE\": the tooltip decides", function()
    -- C_Item.GetItemInfo answers nil until the item is cached (bag items right after login), so
    -- bindType is nil while C_Item.IsBound already answers false for the unbound BoE.
    local inst = gearInstance("geared", function(M) M.__gear.pending[Items.db.boe_legs.id] = true end)
    local I = inst.NS.ItemInfo
    local info = I.FromBag(0, 3)
    assertNil(info.bindType, "the scene: bindType unknown")
    -- red under: readBind answering "none" for bound == false and bindType == nil (the BoE then enters
    -- Inventory.Cache, is picked for an outfit and binds when worn).
    assertEqual(I.Bind(info), "boe", "the Binds when equipped line")
end)

test("itemlink: a bind read off a tooltip with no data is not cached", function()
    local inst = gearInstance("geared", function(M) M.__gear.pending[Items.db.boe_legs.id] = true end)
    local I, M = inst.NS.ItemInfo, inst.mocks
    local realTip = M.C_TooltipInfo.GetBagItem
    M.C_TooltipInfo.GetBagItem = function() return nil end
    local info = I.FromBag(0, 3)
    assertEqual(I.Bind(info), "none", "nothing to read yet")
    M.C_TooltipInfo.GetBagItem = realTip
    -- red under: II.Bind caching the unsettled "none" (the BoE reads "none" for good).
    assertEqual(I.Bind(info), "boe", "asked again once the tooltip has data")
    assertEqual(info.bind, "boe", "and cached then")
end)

test("itemlink: UniqueKeys reads the limit category, the item itself, or nothing", function()
    local inst = gearInstance("unique_rings")
    local I = inst.NS.ItemInfo
    local function keysOf(def)
        local k = I.UniqueKeys(I.FromLink(def.link))
        if not k then return nil end
        local out = {}
        for key in pairs(k) do out[#out + 1] = key end
        table.sort(out)
        return table.concat(out, ",")
    end
    assertEqual(keysOf(DB.ring_unique_a), "c701", "a limit category")
    assertEqual(keysOf(DB.ring_unique_b), "c701", "the same category joins them")
    assertEqual(keysOf(DB.ring_self_unique), "i212034", "unique-equipped itself")
    -- red under: readUnique dropping its `not u.unique` return (a plain ring reads unique).
    assertNil(keysOf(DB.ring_plain_a), "not unique")
end)

test("itemlink: without the uniqueness API, UniqueKeys reads the tooltip lines", function()
    local inst = gearInstance("unique_rings", function(M) M.C_Item.GetItemUniquenessByID = nil end)
    local I = inst.NS.ItemInfo
    local a = I.UniqueKeys(I.FromLink(DB.ring_unique_a.link))
    local b = I.UniqueKeys(I.FromLink(DB.ring_unique_b.link))
    -- red under: dropping the ITEM_LIMIT_CATEGORY_MULTIPLE pattern (no key for either signet).
    assertTrue(a ~= nil and a["nSeal of the Bench"], "the category name from the tooltip")
    assertTrue(b ~= nil and b["nSeal of the Bench"], "the same key for the second signet")
    assertTrue(I.UniqueKeys(I.FromLink(DB.ring_self_unique.link))["i212034"], "ITEM_UNIQUE_EQUIPPABLE")
    assertNil(I.UniqueKeys(I.FromLink(DB.ring_plain_a.link)))
end)

test("itemlink: Usable asks the client, and without it any red line after the name refuses (B14)", function()
    -- legacy: always usable (the red cRequiresPrefix no modern line carries; INV §19 B14,
    -- OutfitterInventory.lua:425); fixed: any red line after the name refuses.
    local inst = gearInstance("geared")
    local I = inst.NS.ItemInfo
    assertFalse(I.Usable(I.FromLink(DB.unusable_helm.link)), "CanUseItem false")
    assertTrue(I.Usable(I.FromSlot("HeadSlot")), "CanUseItem true")

    local fb = gearInstance("geared", function(M) M.C_PlayerInfo.CanUseItem = nil end)
    local F = fb.NS.ItemInfo
    -- red under: the legacy "Requires" prefix match (the red "Requires Level 90" line is missed).
    assertFalse(F.Usable(F.FromLink(DB.unusable_helm.link)), "the red requirement line")
    assertTrue(F.Usable(F.FromSlot("HeadSlot")), "no red line")
    -- The name line is never a requirement: a legendary's orange name (hue 30) is not a refusal.
    -- red under: testing the first (name) line too.
    fb.mocks.C_TooltipInfo.GetHyperlink = function()
        return { lines = { { leftText = "Orange Thing", leftColor = { r = 1, g = 0.5, b = 0 } },
                           { leftText = "Binds when picked up", leftColor = { r = 1, g = 1, b = 1 } } } }
    end
    assertTrue(F.Usable(F.FromLink(DB.neck_chain.link)), "an orange name")
end)

-- ── identity and comparison ───────────────────────────────────────────────────────────────────

test("itemlink: Exact compares every EXACT field, the difficulty included", function()
    local I = II()
    local a = I.ParseLink(DB.chest_champion.link)
    local b = I.ParseLink(DB.chest_champion.link)
    assertTrue(I.Exact(a, b), "the same link")
    assertFalse(I.Exact(a, I.ParseLink(DB.chest_hero.link)), "another track")
    -- red under: dropping any one name from EXACT_FIELDS (diff is the one FindItem used to skip).
    local alt = { suffix = 9, enchant = 9, gems = "9:0:0:0", uid = 9, upType = 9, diff = 9, bonus = "9",
                  mods = "1=9", azerite = "9" }
    for field, v in pairs(alt) do
        local c = I.ParseLink(DB.chest_champion.link)
        c[field] = v
        assertFalse(I.Exact(a, c), field .. " differs")
    end
    -- An old record that lacks a field matches its default.
    local old = I.ParseLink(DB.ring_plain_a.link)
    old.azerite, old.mods = nil, nil
    local fresh = I.ParseLink(DB.ring_plain_a.link)
    fresh.azerite = ""
    assertTrue(I.Exact(old, fresh), "nil reads as the canonical empty")
end)

test("itemlink: SameIdentity is the same id and suffix, or an alias", function()
    local I = II()
    assertTrue(I.SameIdentity({ id = 5, suffix = 0 }, { id = 5, suffix = 0 }))
    assertFalse(I.SameIdentity({ id = 5, suffix = 1 }, { id = 5, suffix = 2 }), "suffix")
    assertFalse(I.SameIdentity({ id = 5 }, { id = 6 }), "id")
    -- red under: dropping the ALIASES branch.
    assertTrue(I.SameIdentity({ id = 46069 }, { id = 46106 }), "Alliance Lance finds the Argent Lance")
    assertTrue(I.SameIdentity({ id = 18608, suffix = 1 }, { id = 18609 }), "Benediction / Anathema")
end)

test("itemlink: UsesBothHands and MetaSlot follow the Titan's Grip spec", function()
    local inst = gearInstance("geared")
    local I, W, PS = inst.NS.ItemInfo, inst.mocks.__world, inst.NS.PlayerState
    PS.Refresh()
    local great = I.FromBag(0, 1)
    local sword = { invType = "INVTYPE_WEAPON", meta = "Weapon0Slot" }
    assertTrue(I.UsesBothHands(great), "an Arms warrior's greatsword")
    assertEqual(I.MetaSlot(great), "TwoHandSlot")
    assertFalse(I.UsesBothHands(sword))
    assertEqual(I.MetaSlot(sword), "Weapon0Slot")
    assertNil(I.MetaSlot(I.FromSlot("HeadSlot")))
    W:setClass("WARRIOR", 2)
    PS.Refresh()
    -- red under: UsesBothHands ignoring PS.CanDualWield2H.
    assertFalse(I.UsesBothHands(great), "Fury grips it in one hand")
    assertEqual(I.MetaSlot(great), "Weapon0Slot")
end)

test("itemlink: LinkInfoLines names every field, and passes each through SafeToString", function()
    local I = II()
    local lines = I.LinkInfoLines(DB.wrist_plate.link)
    local text = table.concat(lines, "\n")
    assertTrue(text:find("id: 212395", 1, true) ~= nil, "id")
    assertTrue(text:find("bonus: 10353:1520:10255", 1, true) ~= nil, "bonus")
    assertTrue(text:find("mods: 28=2734", 1, true) ~= nil, "mods")
    assertTrue(text:find("diff: 0", 1, true) ~= nil, "diff")
    -- red under: concatenating the raw link (the secret trap raises on `..`).
    local secretLines = I.LinkInfoLines(T.secret(DB.wrist_plate.link))
    assertEqual(secretLines[1], "link: " .. T.NS.SafeToString(T.secret("x")), "the secret masked")
    assertEqual(secretLines[2], T.NS.L["Not a readable item link."])
    assertEqual(#secretLines, 2)
end)

-- ── PlayerState ───────────────────────────────────────────────────────────────────────────────

-- A fresh instance with PlayerState resumed, Equip faked, and the PLAYER_STATE_CHANGED log.
local function psScene(scenario)
    local inst = gearInstance(scenario or "geared")
    local NS = inst.NS
    local equip = T.fake(NS, "Equip", { Batch = function(fn) fn() end, DelayUntil = true, Request = true })
    local heard = {}
    local bus = NS.NewBusTarget()
    bus:RegisterMessage(NS.MSG.PLAYER_STATE_CHANGED, function(_, key, value)
        heard[#heard + 1] = key .. "=" .. tostring(value)
    end)
    NS.PlayerState.Resume()
    for i = #heard, 1, -1 do heard[i] = nil end
    return inst, NS, inst.mocks, equip, heard
end

local function psRegistrations(M)
    local out = {}
    for _, r in ipairs(M.__registrations()) do
        if r.kind == "event" or r.kind == "unit" or r.kind == "frame" then
            out[#out + 1] = r.event .. (r.unit and ("@" .. r.unit) or "")
        end
    end
    table.sort(out)
    return out
end

test("player state: Resume registers the design's events, the casts for the player only", function()
    local inst = gearInstance("geared")
    local before = #psRegistrations(inst.mocks)
    inst.NS.PlayerState.Resume()
    local regs = table.concat(psRegistrations(inst.mocks), ",")
    for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD", "PLAYER_ALIVE",
                          "PLAYER_UNGHOST", "PLAYER_TALENT_UPDATE", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
                          "PLAYER_ENTERING_WORLD" }) do
        assertTrue(regs:find(ev, 1, true) ~= nil, ev)
    end
    for _, ev in ipairs({ "SENT", "START", "STOP", "INTERRUPTED", "FAILED", "FAILED_QUIET", "SUCCEEDED",
                          "CHANNEL_START", "CHANNEL_STOP" }) do
        -- red under: RegisterEvent for the casts (every unit's casts would reach the handler).
        assertTrue(regs:find("UNIT_SPELLCAST_" .. ev .. "@player", 1, true) ~= nil, ev .. " for the player")
    end
    assertFalse(regs:find("CHARACTER_POINTS_CHANGED", 1, true) ~= nil, "the retired talent event")
    assertTrue(#psRegistrations(inst.mocks) > before)
end)

test("player state: Suspend drops every registration; Resume rebuilds them", function()
    local _, NS, M = psScene()
    local on = table.concat(psRegistrations(M), ",")
    NS.PlayerState.Suspend()
    -- red under: Suspend leaving the unit frame's casts registered.
    assertEqual(#psRegistrations(M), 0, "still registered: " .. table.concat(psRegistrations(M), ","))
    NS.PlayerState.Resume()
    assertEqual(table.concat(psRegistrations(M), ","), on)
end)

test("player state: the regen edges set and clear combat; leaving it flushes through Equip.Batch", function()
    local _, NS, M, equip, heard = psScene()
    local PS = NS.PlayerState
    M.__lockdown = true
    M.__fire("PLAYER_REGEN_DISABLED")
    assertTrue(PS.InCombat())
    PS.SetMaybeInCombat(true)
    assertTrue(PS.MaybeInCombat())
    M.__lockdown = false
    M.__fire("PLAYER_REGEN_ENABLED")
    assertFalse(PS.InCombat())
    -- red under: REGEN_ENABLED leaving MaybeInCombat set (the old RegenEnabled cleared both).
    assertFalse(PS.MaybeInCombat(), "MaybeInCombat clears out of combat")
    assertEqual(equip.__count("Batch"), 1, "the empty bracket that flushes queued swaps")
    assertEqual(type(equip.__calls[1][2]), "function")
    assertEqual(table.concat(heard, ","), "combat=true,combat=false")
end)

test("player state: a cast or channel ending delays the equip by half a second", function()
    local _, NS, M, equip, heard = psScene()
    local PS = NS.PlayerState
    M.GetTime = function() return 100 end
    M.__fire("UNIT_SPELLCAST_START", "player", "cast-1", 133)
    assertTrue(PS.IsCasting())
    M.__fire("UNIT_SPELLCAST_STOP", "player", "cast-1", 133)
    assertFalse(PS.IsCasting())
    assertEqual(equip.__count("DelayUntil"), 1)
    assertEqual(equip.__calls[1][2], 100.5, "GetTime() + 0.5")
    -- red under: delaying on every stop (a stop with no cast in flight is not a cast end).
    M.__fire("UNIT_SPELLCAST_STOP", "player", "cast-2", 133)
    assertEqual(equip.__count("DelayUntil"), 1, "a stop with no cast")
    M.__fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-3", 5143)
    assertTrue(PS.IsChanneling())
    M.__fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "cast-3", 5143)
    assertFalse(PS.IsChanneling())
    assertFalse(PS.IsCasting())
    assertEqual(equip.__count("DelayUntil"), 2)
    assertEqual(table.concat(heard, ","), "casting=true,casting=false,casting=true,casting=false")
end)

test("player state: another unit's cast is ignored", function()
    local _, NS, M, equip = psScene()
    -- red under: dropping the unit check (the harness fires a unit event at every holder).
    M.__fire("UNIT_SPELLCAST_START", "target", "cast-9", 133)
    assertFalse(NS.PlayerState.IsCasting())
    assertEqual(#equip.__calls, 0)
end)

test("player state: the last successful cast's plain spell id is kept; a secret one is not", function()
    local _, NS, M = psScene()
    local PS = NS.PlayerState
    assertNil(PS.LastCastSpellID())
    M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 1459)
    assertEqual(PS.LastCastSpellID(), 1459)
    -- red under: storing the raw argument (a secret would reach NS.TriggerParams.CaptureLastCast).
    M.__fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", T.secret(2139))
    assertEqual(PS.LastCastSpellID(), 1459, "the secret left the last plain id in place")
end)

test("player state: death and life, and coming back asks Equip for an update", function()
    local _, NS, M, equip, heard = psScene()
    local PS = NS.PlayerState
    M.__fire("PLAYER_DEAD")
    assertTrue(PS.IsDead())
    M.__fire("PLAYER_ALIVE")
    assertFalse(PS.IsDead())
    assertEqual(equip.__count("Request"), 1)
    -- Releasing the spirit fires PLAYER_ALIVE as a ghost: the client still says dead-or-ghost.
    M.__fire("PLAYER_DEAD")
    M.__world:setUnit("player", { ghost = true })
    M.__fire("PLAYER_ALIVE")
    -- red under: PLAYER_ALIVE clearing the flag without re-reading UnitIsDeadOrGhost.
    assertTrue(PS.IsDead(), "a ghost is not alive")
    M.__world:setUnit("player", { ghost = false })
    M.__fire("PLAYER_UNGHOST")
    assertFalse(PS.IsDead())
    assertEqual(table.concat(heard, ","), "dead=true,dead=false,dead=true,dead=false")
end)

test("player state: the spec follows the spec events, and Fury warriors dual wield two-handers", function()
    local _, NS, M, _, heard = psScene()
    local PS = NS.PlayerState
    assertEqual(PS.Spec(), 1)
    assertFalse(PS.CanDualWield2H())
    M.__world:setClass("WARRIOR", 2)
    M.__fire("ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "player")
    assertEqual(PS.Spec(), 2)
    assertTrue(PS.CanDualWield2H())
    assertEqual(table.concat(heard, ","), "spec=2")
    M.__world:setClass("ROGUE", 2)
    M.__fire("PLAYER_TALENT_UPDATE")
    -- red under: CanDualWield2H testing the spec alone.
    assertFalse(PS.CanDualWield2H(), "a spec-2 rogue")
    M.__gear.canDualWield = true
    assertTrue(PS.CanDualWield(), "CanDualWield is the client's")
    M.__gear.canDualWield = false
    assertFalse(PS.CanDualWield())
end)

test("player state: Refresh re-reads combat, death and spec, and sends only what moved", function()
    local _, NS, M, equip, heard = psScene()
    local PS = NS.PlayerState
    M.__lockdown = true
    M.__fire("PLAYER_REGEN_DISABLED")
    PS.SetMaybeInCombat(true)
    M.__fire("PLAYER_DEAD")
    for i = #heard, 1, -1 do heard[i] = nil end
    -- Across a loading screen the client left combat and the player was revived: no edge arrived.
    M.__lockdown = false
    PS.Refresh()
    assertFalse(PS.InCombat(), "a stale combat flag")
    -- red under: Refresh leaving MaybeInCombat set when out of lockdown.
    assertFalse(PS.MaybeInCombat(), "a stale MaybeInCombat")
    assertFalse(PS.IsDead(), "a stale death")
    assertEqual(table.concat(heard, ","), "combat=false,dead=false")
    PS.Refresh()
    -- red under: Refresh sending every key every time.
    assertEqual(#heard, 2, "nothing moved, nothing sent")
    assertEqual(#equip.__calls, 0, "Refresh never equips")
end)

test("player state: Refresh re-reads the cast and the channel through Compat (design §5.2)", function()
    local _, NS, M, equip, heard = psScene()
    local PS = NS.PlayerState
    -- A cast began while the module was not listening: no SENT/START edge arrived.
    M.__world:setUnit("player", { casting = { name = "Hearthstone", spellID = 8690 } })
    PS.Refresh()
    -- red under: Refresh not reading Compat.PlayerCasting.
    assertTrue(PS.IsCasting(), "a cast already under way")
    assertEqual(table.concat(heard, ","), "casting=true")
    M.__world:setUnit("player", { casting = false, channeling = { name = "Drain Soul" } })
    PS.Refresh()
    assertFalse(PS.IsCasting(), "the cast ended unseen")
    assertTrue(PS.IsChanneling(), "a channel already under way")
    -- red under: Refresh announcing each cast flag on its own (casting -> channeling is no edge).
    assertEqual(#heard, 1, "the union did not move")
    M.__world:setUnit("player", { channeling = false })
    PS.Refresh()
    assertFalse(PS.IsChanneling(), "the channel ended unseen")
    assertEqual(table.concat(heard, ","), "casting=true,casting=false")
    assertEqual(#equip.__calls, 0, "Refresh never equips")
end)

test("player state: a sealed cast reading leaves the cast flags alone on Refresh (Resume)", function()
    local _, NS, M = psScene()
    local PS = NS.PlayerState
    M.__fire("UNIT_SPELLCAST_START", "player", "cast-1", 133)
    M.UnitCastingInfo = function() return T.secret("Hearthstone") end
    local restore = T.installSecretValue()
    local ok, err = pcall(function()
        -- red under: PlayerCasting reading a sealed name as "not casting".
        PS.Refresh()
        assertTrue(PS.IsCasting(), "unknown is not an edge")
        assertNil((NS.Compat.PlayerCasting()), "sealed answers nil")
    end)
    restore()
    if not ok then error(err, 0) end
end)

test("player state: PLAYER_ENTERING_WORLD clears a cast flag whose reading is sealed or missing", function()
    -- legacy: PlayerEnteringWorld set IsCasting and IsChanneling false unconditionally (Outfitter.lua
    -- :1525-1527, INV §6.1 PEW "Clear casting flags"); kept: a STOP lost across a loading screen
    -- cannot hold every equip at the casting gate.
    local _, NS, M, _, heard = psScene()
    local PS = NS.PlayerState
    M.__fire("UNIT_SPELLCAST_START", "player", "cast-1", 133)
    M.__fire("UNIT_SPELLCAST_CHANNEL_START", "player", "cast-2", 5143)
    for i = #heard, 1, -1 do heard[i] = nil end
    M.UnitCastingInfo = function() return T.secret("Hearthstone") end
    M.UnitChannelInfo = nil
    local restore = T.installSecretValue()
    local ok, err = pcall(function()
        M.__fire("PLAYER_ENTERING_WORLD", false, true)
        -- red under: PEW calling PS.Refresh (the keep-on-nil read) instead of the reset.
        assertFalse(PS.IsCasting(), "a sealed cast reading clears on PEW")
        -- red under: the reset applied to the cast flag only.
        assertFalse(PS.IsChanneling(), "a missing channel API clears on PEW")
        assertEqual(table.concat(heard, ","), "casting=false", "one union edge")
    end)
    restore()
    if not ok then error(err, 0) end
end)

test("player state: PLAYER_ENTERING_WORLD keeps a cast the client still reports", function()
    local _, NS, M = psScene()
    M.__world:setUnit("player", { casting = { name = "Hearthstone", spellID = 8690 } })
    M.__fire("PLAYER_ENTERING_WORLD", false, true)
    -- red under: PEW clearing the flags without reading Compat.PlayerCasting.
    assertTrue(NS.PlayerState.IsCasting(), "a plain reading wins over the reset")
end)

test("player state: PLAYER_ENTERING_WORLD refreshes; in lockdown it keeps combat", function()
    local _, NS, M, _, heard = psScene()
    local PS = NS.PlayerState
    M.__lockdown = true
    M.__fire("PLAYER_ENTERING_WORLD", false, true)
    -- red under: PEW not calling Refresh (combat entered across the loading screen stays unseen).
    assertTrue(PS.InCombat(), "lockdown read as combat")
    assertEqual(table.concat(heard, ","), "combat=true")
    PS.SetMaybeInCombat(true)
    M.__fire("PLAYER_ENTERING_WORLD", false, true)
    assertTrue(PS.MaybeInCombat(), "MaybeInCombat survives while still locked down")
end)

test("player state: the interrupt-casting flag is the triggers' to set", function()
    local PS = T.NS.PlayerState
    assertFalse(PS.InterruptCasting())
    PS.SetInterruptCasting(true)
    assertTrue(PS.InterruptCasting())
    -- red under: SetInterruptCasting ignoring a false (`flags.interrupt = flags.interrupt or on`).
    PS.SetInterruptCasting(false)
    assertFalse(PS.InterruptCasting())
end)

test("player state: Resume reads the current state before any event", function()
    local inst = gearInstance("geared", function(M) M.__lockdown = true end)
    local PS = inst.NS.PlayerState
    -- red under: Resume registering without calling Refresh.
    PS.Resume()
    assertTrue(PS.InCombat(), "a login in combat")
    assertEqual(PS.Spec(), 1)
end)
