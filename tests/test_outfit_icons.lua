-- tests/test_outfit_icons.lua — the outfit icon model (sheet and window feedback plan Task 3.5; design
-- G5, G6): NS.OutfitIcon, the one resolver the row, the bar and the broker draw, and NS.Outfits.SetIcon,
-- the one writer the icon browser calls. A 1.1.0 fileID keeps drawing; a glyph carries its tint; an
-- Equipment Manager outfit's glyph is kept per character, keyed by its set, and never written to the set.

local T = _G.OUTFITTERREBORN_TEST
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local WILDCARD = 134400

-- A fresh instance on the em_sets scenario, the first scan settled and (unless `noSync`) the sets mirrored.
local function scene(noSync)
    local inst = unitLoad({ mutate = function(M) M.__gear:load("em_sets") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    M.__fireTimers()
    T.fake(NS, "Dock", { IsShown = function() return false end })
    T.fake(NS, "TriggerBinder", { Unbind = true })
    if not noSync then NS.EM.Sync() end
    return NS, M
end

local function emOutfit(NS, name)
    for id, rec in pairs(NS.db.char.outfits) do
        if rec.kind == "em" and rec.name == name then return id, rec end
    end
    return nil
end

local function calls(M, name)
    local n = 0
    for _, c in ipairs(M.__equipCalls) do if c[1] == name then n = n + 1 end end
    return n
end

local function hear(NS, key)
    local heard = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG[key], function(_, ...) heard[#heard + 1] = { ... } end)
    return heard
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

-- A glyph path at this addon's folder, as the browser's Glyphs tab hands it to onChoose.
local function glyph(NS, name) return assert(NS.Icon(name or "ph:sword"), "the glyph ships") end

test("icons: NS.OutfitIcon and NS.Outfits.SetIcon are published, and char.emIcons defaults empty", function()
    local NS = scene()
    assertEqual(type(NS.OutfitIcon), "function")
    assertEqual(type(NS.Outfits.SetIcon), "function")
    assertEqual(type(NS.db.char.emIcons), "table")
    assertEqual(next(NS.db.char.emIcons), nil)
end)

test("icons: a 1.1.0 fileID draws as before", function()
    local NS = scene()
    -- The 1.1.0 shape: a plain number on the record, written by the old chooser or the bar's alt-drop.
    local id = NS.Outfits.Create("Old", {})
    NS.Outfits.Get(id).icon = 135349
    local tex, r, g, b = NS.OutfitIcon(NS.Outfits.Get(id))
    assertEqual(tex, 135349)
    assertTrue(r == 1 and g == 1 and b == 1, "a fileID is drawn untinted")
    -- red under: a stale iconColor tinting a fileID (only a glyph takes a tint).
    NS.Outfits.Get(id).iconColor = "ff0000"
    tex, r, g, b = NS.OutfitIcon(NS.Outfits.Get(id))
    assertEqual(tex, 135349)
    assertTrue(r == 1 and g == 1 and b == 1, "a fileID ignores a color")
end)

test("icons: no icon falls through trigger, item, then the coat hanger", function()
    local NS, M = scene()
    local O = NS.Outfits
    local solo = O.Create("Solo", {})
    NS.SetByPath("outfit.trigger.id", "INSTANCE_DIFFICULTY", solo)
    assertEqual((NS.OutfitIcon(O.Get(solo))), 132132, "the trigger's descriptor icon")
    local info = NS.ItemInfo.FromBag(0, 1)
    local single = O.Create("Hero", { ChestSlot = NS.ItemInfo.Snapshot(info) })
    assertEqual((NS.OutfitIcon(O.Get(single))), M.C_Item.GetItemIconByID(info.id), "the single item's icon")
    local plain = O.Create("Plain", { ChestSlot = NS.ItemInfo.Snapshot(info), HeadSlot = { id = 0 } })
    local tex, r, g, b = NS.OutfitIcon(O.Get(plain))
    -- red under: the legacy plain icon (132662) as the last rung.
    assertEqual(tex, NS.Constants.DEFAULT_OUTFIT_ICON)
    assertTrue(r == 1 and g == 1 and b == 1, "the coat hanger is plain white on an outfit")
    assertEqual((NS.OutfitIcon(nil)), NS.Constants.DEFAULT_OUTFIT_ICON, "no record draws the coat hanger")
end)

test("icons: a glyph with a color tints", function()
    local NS = scene()
    local O = NS.Outfits
    local id = O.Create("Glyph", {})
    local edited = hear(NS, "OUTFIT_EDITED")
    assertTrue(O.SetIcon(id, glyph(NS), "ff8000"))
    local rec = O.Get(id)
    assertEqual(rec.icon, glyph(NS))
    assertEqual(rec.iconColor, "ff8000")
    local tex, r, g, b = NS.OutfitIcon(rec)
    assertEqual(tex, glyph(NS))
    assertTrue(near(r, 1) and near(g, 128 / 255) and near(b, 0), "tinted " .. r .. "," .. g .. "," .. b)
    assertTrue(#edited >= 1 and edited[#edited][1] == id and edited[#edited][2] == "icon", "OUTFIT_EDITED icon")
    -- White is no color (the browser hands nil, ColorFrom answers false): drawn untinted.
    assertTrue(O.SetIcon(id, glyph(NS), false))
    assertNil(O.Get(id).iconColor)
    tex, r, g, b = NS.OutfitIcon(O.Get(id))
    assertEqual(tex, glyph(NS))
    assertTrue(r == 1 and g == 1 and b == 1, "an uncolored glyph is white")
    -- red under: a fileID pick that keeps the glyph's color.
    assertTrue(O.SetIcon(id, glyph(NS), "00ff00"))
    assertTrue(O.SetIcon(id, 135349, "00ff00"))
    assertEqual(O.Get(id).icon, 135349)
    assertNil(O.Get(id).iconColor, "a fileID clears the glyph's color")
end)

test("icons: the icon row takes a fileID, a glyph or nil, and refuses any other string or color", function()
    local NS = scene()
    local id = NS.Outfits.Create("Rows", {})
    assertTrue(NS.SetByPath("outfit.icon", glyph(NS, "settings"), id), "an Open Iconic glyph")
    -- red under: a validate that takes any string (a texture path is not a glyph).
    assertFalse(NS.SetByPath("outfit.icon", "Interface\\Icons\\INV_Misc_QuestionMark", id))
    assertFalse(NS.SetByPath("outfit.icon", 1.5, id))
    assertTrue(NS.SetByPath("outfit.iconColor", "a0b1c2", id))
    assertFalse(NS.SetByPath("outfit.iconColor", "A0B1C2", id), "upper case is not a stored color")
    assertFalse(NS.SetByPath("outfit.iconColor", "red", id))
    assertTrue(NS.SetByPath("outfit.iconColor", nil, id))
    assertNil(NS.Outfits.Get(id).iconColor)
end)

test("icons: 134400 stores nil", function()
    local NS = scene()
    local O = NS.Outfits
    local id = O.Create("Wild", {})
    assertTrue(O.SetIcon(id, 135349))
    assertTrue(O.SetIcon(id, WILDCARD))
    -- red under: the wildcard stored as an icon.
    assertNil(O.Get(id).icon)
    assertTrue(O.SetIcon(id, glyph(NS), "ff0000"))
    assertTrue(O.SetIcon(id, nil))
    assertNil(O.Get(id).icon)
    assertNil(O.Get(id).iconColor, "no icon, no color")
end)

test("icons: a glyph on an EM outfit is kept per character and the set is not modified", function()
    local NS, M = scene()
    local id, rec = emOutfit(NS, "Tank")
    local before = calls(M, "ModifyEquipmentSet")
    assertTrue(NS.Outfits.SetIcon(id, glyph(NS), "00ff00"))
    -- red under: a glyph path handed to ModifyEquipmentSet (the set takes a fileID only).
    assertEqual(calls(M, "ModifyEquipmentSet"), before, "the set is not written")
    assertEqual(NS.EM.Icon(rec), 132341, "the set keeps its own icon")
    local saved = NS.db.char.emIcons[rec.setID]
    assertEqual(type(saved), "table")
    assertEqual(saved.icon, glyph(NS))
    assertEqual(saved.color, "00ff00")
    assertNil(rec.icon, "the mirror's record is not the store")
    local tex, r, g, b = NS.OutfitIcon(rec)
    assertEqual(tex, glyph(NS), "the override is drawn instead of the set's icon")
    assertTrue(near(r, 0) and near(g, 1) and near(b, 0))
end)

test("icons: an EM outfit draws its set's icon, and a fileID on it goes to the set and clears the override", function()
    local NS, M = scene()
    local id, rec = emOutfit(NS, "Tank")
    assertEqual((NS.OutfitIcon(rec)), 132341, "the set's icon")
    NS.Outfits.SetIcon(id, glyph(NS), "00ff00")
    local before = calls(M, "ModifyEquipmentSet")
    assertTrue(NS.Outfits.SetIcon(id, 135349))
    assertEqual(calls(M, "ModifyEquipmentSet"), before + 1)
    assertEqual(NS.EM.Icon(rec), 135349)
    -- red under: an override left behind, still drawn over the set's new icon.
    assertNil(NS.db.char.emIcons[rec.setID])
    local tex, r, g, b = NS.OutfitIcon(rec)
    assertEqual(tex, 135349)
    assertTrue(r == 1 and g == 1 and b == 1)
    -- The wildcard on an EM outfit writes the set's 134400, as the old chooser did.
    assertTrue(NS.Outfits.SetIcon(id, WILDCARD))
    assertNil(NS.EM.Icon(rec))
end)

-- The outfit bar's Alt-drop wrote `outfit.icon` on any outfit, Equipment Manager mirrors included, and
-- that row was drawn before the override and the set's icon, so no Change icon pick ever showed.
test("icons: an EM outfit's stale own icon never hides its override or its set's icon", function()
    local NS = scene()
    local id, rec = emOutfit(NS, "Tank")
    rec.icon = 136000
    -- red under: ownIcon reading rec.icon first for an EM outfit.
    assertEqual((NS.OutfitIcon(rec)), 132341, "a stale own icon hid the set's icon")
    assertTrue(NS.Outfits.SetIcon(id, glyph(NS), "00ff00"))
    assertEqual((NS.OutfitIcon(rec)), glyph(NS), "a stale own icon hid the glyph override")
    -- The EM writer drops the stale row, so Outfitter chooses is not shadowed by it either.
    assertNil(rec.icon, "SetIcon on an EM outfit left its own icon behind")
    assertTrue(NS.Outfits.SetIcon(id, WILDCARD))
    assertTrue(NS.OutfitIcon(rec) ~= 136000, "the stale own icon came back")
end)

test("icons: deleting an EM set clears its override", function()
    local NS, M = scene()
    local tankId, tank = emOutfit(NS, "Tank")
    local swordId, sword = emOutfit(NS, "Big Sword")
    NS.Outfits.SetIcon(tankId, glyph(NS), "00ff00")
    NS.Outfits.SetIcon(swordId, glyph(NS, "settings"))
    local tankSet, swordSet = tank.setID, sword.setID
    -- Deleted in the Blizzard UI: the next sync removes the mirror, and the set id may be reused.
    M.C_EquipmentSet.DeleteEquipmentSet(tankSet)
    M.__now = M.__now + 5
    NS.EM.Sync()
    assertNil(NS.Outfits.Get(tankId))
    -- red under: an override outliving its set (a reused set id would draw a stranger's glyph).
    assertNil(NS.db.char.emIcons[tankSet])
    -- Deleted from here: the outfit store's Delete deletes the set and the override with it.
    NS.Outfits.Delete(swordId)
    assertNil(NS.db.char.emIcons[swordSet])
end)

test("icons: storing a glyph outfit on the server keeps the glyph as the set's override, and back", function()
    local NS, M = scene()
    local O = NS.Outfits
    local id = O.Create("Glow", { HeadSlot = { id = 0 } })
    O.SetIcon(id, glyph(NS), "123456")
    local ok, _, emId = NS.EM.StoreOnServer(id)
    assertTrue(ok)
    -- red under: the glyph path handed to CreateEquipmentSet.
    local created
    for _, c in ipairs(M.__equipCalls) do if c[1] == "CreateEquipmentSet" then created = c end end
    assertEqual(created[3], WILDCARD, "the set is created with the wildcard")
    local em = O.Get(emId)
    assertEqual(NS.db.char.emIcons[em.setID].icon, glyph(NS))
    assertEqual(NS.db.char.emIcons[em.setID].color, "123456")
    assertEqual((NS.OutfitIcon(em)), glyph(NS))
    M.__now = M.__now + 5
    local setID = em.setID
    local back = NS.EM.StoreLocally(emId)
    local rec = O.Get(back)
    assertEqual(rec.icon, glyph(NS))
    assertEqual(rec.iconColor, "123456")
    assertNil(NS.db.char.emIcons[setID], "the set is gone, and its override with it")
end)

test("icons: a mirror matched to a new set id keeps its glyph override under that id", function()
    local NS, M = scene(true)
    local id = NS.Outfits.Create("TANK", {}, { kind = "em", setID = 99 })
    assertTrue(NS.Outfits.SetIcon(id, glyph(NS), "abcdef"))
    assertEqual(NS.db.char.emIcons[99].icon, glyph(NS))
    NS.EM.Sync()
    local setID = M.C_EquipmentSet.GetEquipmentSetID("Tank")
    assertEqual(NS.Outfits.Get(id).setID, setID)
    -- red under: an override left at the old id (lost here, and drawn on whatever set takes id 99).
    assertNil(NS.db.char.emIcons[99])
    assertEqual(NS.db.char.emIcons[setID].color, "abcdef")
    assertEqual((NS.OutfitIcon(NS.Outfits.Get(id))), glyph(NS))
end)

test("icons: two mirrors that trade set ids in one sync each keep their own glyph", function()
    local NS, M = scene()
    local tankId, tank = emOutfit(NS, "Tank")
    local swordId, sword = emOutfit(NS, "Big Sword")
    local tankSet, swordSet = tank.setID, sword.setID
    -- A stored session in which the client numbered the two sets the other way round.
    local icons = NS.db.char.emIcons
    tank.setID, sword.setID = swordSet, tankSet
    icons[swordSet] = { icon = glyph(NS), color = "00ff00" }
    icons[tankSet] = { icon = glyph(NS, "settings"), color = "0000ff" }
    M.__now = M.__now + 5
    NS.EM.Sync()
    assertEqual(NS.Outfits.Get(tankId).setID, tankSet)
    assertEqual(NS.Outfits.Get(swordId).setID, swordSet)
    -- red under: re-keying one mirror at a time (the first move overwrites the second's glyph).
    assertEqual(icons[tankSet] and icons[tankSet].color, "00ff00", "Tank keeps its glyph")
    assertEqual(icons[swordSet] and icons[swordSet].color, "0000ff", "Big Sword keeps its glyph")
end)

test("icons: a pruned mirror on the set id another mirror moved to does not take that mirror's glyph", function()
    local NS, M = scene()
    local tankId, tank = emOutfit(NS, "Tank")
    local tankSet = tank.setID
    local icons = NS.db.char.emIcons
    -- Tank was stored under a stale id; a mirror whose set is gone holds Tank's real id.
    tank.setID = 77
    icons[77] = { icon = glyph(NS), color = "00ff00" }
    local ghost = NS.Outfits.Create("Ghost", {}, { kind = "em", setID = tankSet })
    icons[tankSet] = { icon = glyph(NS, "settings"), color = "0000ff" }
    M.__now = M.__now + 5
    NS.EM.Sync()
    assertNil(NS.Outfits.Get(ghost), "the ghost mirror is pruned")
    assertEqual(NS.Outfits.Get(tankId).setID, tankSet)
    -- red under: the prune's Delete clearing the id Tank's glyph just moved to.
    assertEqual(icons[tankSet] and icons[tankSet].color, "00ff00", "Tank keeps its glyph")
    assertNil(icons[77])
end)

test("icons: deleting a mirror leaves an override another outfit's set id still owns", function()
    local NS = scene(true)
    local O = NS.Outfits
    -- A partial sync (a set unreadable) can leave a stale mirror on an id a matched mirror now holds.
    local a = O.Create("A", {}, { kind = "em", setID = 55 })
    local b = O.Create("B", {}, { kind = "em", setID = 55 })
    assertTrue(O.SetIcon(a, glyph(NS), "00ff00"))
    O.Delete(b)
    -- red under: a Delete that clears the id without asking who else holds it.
    assertEqual(NS.db.char.emIcons[55] and NS.db.char.emIcons[55].color, "00ff00")
    O.Delete(a)
    assertNil(NS.db.char.emIcons[55], "the last holder takes the override with it")
end)
