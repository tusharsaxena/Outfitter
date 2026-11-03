-- tests/test_tooltips.lua — P4.17's tooltips (design §7.10, INV §3.8): the "Used by outfits" line
-- (modules/Tooltips.lua), the compare tooltips (modules/Tooltips_Compare.lua) and the outfit tooltip
-- (modules/OutfitTooltip.lua).
--
-- The line runs through the whole client path: GameTooltip draws a bag, inventory or hyperlink item
-- from C_TooltipInfo (tests/mock_world.lua), and the case runs what TooltipDataProcessor collected.
-- The outfits are real NS.Outfits records over the real NS.Inventory cache. The compare tooltips
-- are driven through the client's own GameTooltip_ShowCompareItem, which the mock really post-hooks.
--
-- NS.Triggers lands in P4.15: the outfit tooltip's trigger description is read from a recorded fake
-- (design §12, the fake rule); test_triggers pins the real descriptor.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local DB = T.fixtures.items.db
local PREFIX = "Equipment Sets: "

-- A fresh instance on `scenario`, both hook sets built (Resume is the lifecycle's stand-up).
local function scene(scenario)
    local inst = T.load({ mutate = function(M) M.__gear:load(scenario or "geared") end })
    local NS, M = inst.NS, inst.mocks
    NS.Tooltips.Resume()
    NS.Compare.Resume()
    return NS, M
end

-- The bank opened through the real scan: Equip (P4.8, a parallel task) answers "not loading" from a
-- recorded fake, the inventory is resumed, and the open bank's sync runs.
local function openBank(NS, M)
    T.fake(NS, "Equip", { SuspendedForLoad = function() return false end })
    NS.Inventory.Resume()
    M.__gear:openBank()
    M.__fireTimers()
end

local function snap(NS, key) return NS.ItemInfo.Snapshot(NS.ItemInfo.FromLink(DB[key].link)) end

-- A native outfit holding fixture items, { [slotName] = itemKey }.
local function outfit(NS, name, keys)
    local items = {}
    for slot, key in pairs(keys) do items[slot] = snap(NS, key) end
    return NS.Outfits.Create(name, items)
end

local function postCall(M, tip)
    return M.__world:tooltipPostCall(M.Enum.TooltipDataType.Item, tip or M.GameTooltip, nil)
end

-- The left texts of a tooltip, in order.
local function texts(tip)
    local out = {}
    for i = 1, tip:NumLines() do out[i] = tip["TextLeft" .. i]:GetText() end
    return out
end

-- The "Equipment Sets:" line and how many there are.
local function usedLine(tip)
    local found, n = nil, 0
    for _, s in ipairs(texts(tip)) do
        if type(s) == "string" and s:sub(1, #PREFIX) == PREFIX then found, n = s, n + 1 end
    end
    return found, n
end

-- ── the "Used by outfits" line ────────────────────────────────────────────────────────────────

test("tooltips: the line lands on bag, player inventory and hyperlink tooltips", function()
    local NS, M = scene()
    outfit(NS, "Tank", { HeadSlot = "head_plate", MainHandSlot = "greatsword", ChestSlot = "chest_hero" })
    local tip = M.GameTooltip
    tip:SetBagItem(0, 1)                 -- the greatsword
    postCall(M)
    local line = usedLine(tip)
    assertTrue(line ~= nil and line:find("Tank", 1, true) ~= nil, "bag item: " .. tostring(line))
    tip:SetInventoryItem("player", 1)    -- the worn helm
    postCall(M)
    assertTrue(usedLine(tip) ~= nil, "the player's own inventory item")
    tip:SetHyperlink(DB.chest_hero.link)
    postCall(M)
    assertTrue(usedLine(tip) ~= nil, "a hyperlink")
    tip:SetBagItem(0, 4)                 -- the hearthstone: no outfit uses it
    postCall(M)
    -- red under: buildLine without its `#names == 0` return (an empty "Equipment Sets: " line).
    assertNil(usedLine(tip), "no outfit, no line")
end)

test("tooltips: another unit's inventory item gets no line", function()
    local NS, M = scene()
    outfit(NS, "Tank", { HeadSlot = "head_plate" })
    local tip = M.GameTooltip
    tip:SetHyperlink(DB.head_plate.link)
    rawset(tip, "__info", { getterName = "GetInventoryItem", getterArgs = { "target", 1 } })
    postCall(M)
    -- red under: dropping the Compat.TooltipInventoryUnit gate from Tooltips.OnItem.
    assertNil(usedLine(tip), "the target's helm is not the player's")
end)

test("tooltips: an inventory tooltip whose unit cannot be read gets no line (O41 fails safe)", function()
    local NS, M = scene()
    outfit(NS, "Tank", { HeadSlot = "head_plate" })
    local tip = M.GameTooltip
    tip:SetHyperlink(DB.head_plate.link)
    rawset(tip, "__info", { getterName = "GetInventoryItem", getterArgs = { T.secret("target"), 1 } })
    postCall(M)
    -- red under: Compat.TooltipInventoryUnit answering nil for an unreadable unit (the gate fails open).
    assertNil(usedLine(tip), "an unreadable unit is not the player")
end)

test("tooltips: the stock shopping tooltips get the line, our own compare tooltips are left to themselves", function()
    local NS, M = scene()
    outfit(NS, "Tank", { HeadSlot = "head_plate" })
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
        local shop = M[name]
        shop:SetHyperlink(DB.head_plate.link)
        postCall(M, shop)
        -- red under: the GameTooltip-only gate (the legacy compare path decorated both, Outfitter.lua:7885-7893).
        assertTrue(usedLine(shop) ~= nil, name)
    end
    local ours = M.CreateFrame("GameTooltip", "OutfitterRebornCompareTooltip9", M.UIParent, "ShoppingTooltipTemplate")
    ours:SetHyperlink(DB.head_plate.link)
    postCall(M, ours)
    -- red under: accepting every tooltip (ours would be decorated twice, by the post-call and by Show).
    assertNil(usedLine(ours), "ours decorate themselves")
end)

test("tooltips: names are colored by status; banked is blue |cff4033ff", function()
    local NS, M = scene("bank_closed")
    openBank(NS, M)
    outfit(NS, "Worn", { HeadSlot = "head_plate" })
    outfit(NS, "Banked", { HeadSlot = "head_plate", LegsSlot = "legs_plate" })
    outfit(NS, "Gone", { HeadSlot = "head_plate", NeckSlot = "neck_chain" })
    local off = outfit(NS, "Off", { HeadSlot = "head_plate" })
    NS.Outfits.Get(off).trigger = { id = "SWIMMING", disabled = true }
    local line = NS.Tooltips.LineFor(DB.head_plate.link)
    assertTrue(line:find(NS.SkinEscape("text.highlight") .. "Worn", 1, true) ~= nil, line)
    -- red under: drawing the banked name in the missing color (the legacy red line).
    assertTrue(line:find("|cff4033ffBanked", 1, true) ~= nil, line)
    assertTrue(line:find(NS.SkinEscape("of.outfit.missing") .. "Gone", 1, true) ~= nil, line)
    assertTrue(line:find(NS.SkinEscape("of.outfit.disabled") .. "Off", 1, true) ~= nil, line)
end)

test("tooltips: the client's Equipment Sets line is replaced, otherwise one line is appended", function()
    local NS, M = scene()
    outfit(NS, "Tank", { HeadSlot = "head_plate" })
    local tip = M.GameTooltip
    tip:SetInventoryItem("player", 1)
    local n = tip:NumLines()
    tip:AddLine(M.EQUIPMENT_SETS:format("Blizzard set"))
    postCall(M)
    local line, count = usedLine(tip)
    -- red under: always appending (the client's own line would stay beside ours).
    assertEqual(count, 1, "one Equipment Sets line")
    assertEqual(tip:NumLines(), n + 1, "replaced in place")
    assertTrue(line:find("Tank", 1, true) ~= nil and not line:find("Blizzard", 1, true), line)
    postCall(M)
    assertEqual(tip:NumLines(), n + 1, "a second pass replaces its own line")
    tip:SetInventoryItem("player", 1)
    postCall(M)
    assertEqual(tip:NumLines(), n + 1, "no client line: appended once")
end)

test("tooltips: a secret line text is skipped, never searched", function()
    local NS, M = scene()
    outfit(NS, "Tank", { HeadSlot = "head_plate" })
    local tip = M.GameTooltip
    tip:SetInventoryItem("player", 1)
    tip:AddLine("x")
    tip["TextLeft" .. tip:NumLines()]:SetText(T.secret(M.EQUIPMENT_SETS:format("hidden")))
    local n = tip:NumLines()
    postCall(M)
    assertEqual(tip:NumLines(), n + 1, "the secret line is left alone and ours appended")
end)

test("tooltips: the line is cached per link and wiped on OUTFIT_EDITED and INVENTORY_CHANGED", function()
    local NS = scene()
    local id = outfit(NS, "Tank", { HeadSlot = "head_plate" })
    local O, calls = NS.Outfits, 0
    local using = O.UsingItem
    O.UsingItem = function(...) calls = calls + 1; return using(...) end
    NS.Tooltips.LineFor(DB.head_plate.link)
    NS.Tooltips.LineFor(DB.head_plate.link)
    -- red under: no cache (every tooltip walks every outfit).
    assertEqual(calls, 1, "the second read is the cache's")
    O.Get(id).name = "Bear"
    O.Changed(id, "items")
    local line = NS.Tooltips.LineFor(DB.head_plate.link)
    -- red under: not wiping on OUTFIT_EDITED (the old name stays).
    assertTrue(line:find("Bear", 1, true) ~= nil, line)
    assertEqual(calls, 2)
    NS.SendBus(NS.MSG.INVENTORY_CHANGED, true, false)
    NS.Tooltips.LineFor(DB.head_plate.link)
    assertEqual(calls, 3, "INVENTORY_CHANGED wipes it")
    NS.Tooltips.Refresh()
    NS.Tooltips.LineFor(DB.head_plate.link)
    assertEqual(calls, 4, "Refresh wipes it")
end)

test("tooltips: off with tooltip.usedBy, silent while stood down, none for a secret link or another tooltip", function()
    local NS, M = scene("secret_slots")
    outfit(NS, "Tank", { HeadSlot = "secret_helm", ChestSlot = "chest_plate" })
    local tip = M.GameTooltip
    NS.db.profile.tooltip.usedBy = false
    tip:SetInventoryItem("player", 5)
    postCall(M)
    -- red under: dropping the tooltip.usedBy read.
    assertNil(usedLine(tip), "the row is off")
    NS.db.profile.tooltip.usedBy = true
    NS.ApplyEnabled(false)
    tip:SetInventoryItem("player", 5)
    postCall(M)
    -- red under: dropping the NS.IsStoodDown() gate.
    assertNil(usedLine(tip), "stood down")
    NS.ApplyEnabled(true)
    tip:SetBagItem(0, 1)                 -- the secret helm
    local Tt, decorated = NS.Tooltips, 0
    local decorate = Tt.Decorate
    Tt.Decorate = function(...) decorated = decorated + 1; return decorate(...) end
    postCall(M)
    Tt.Decorate = decorate
    -- red under: displayedLink without its Secrets.PlainString (the secret link reaches Decorate).
    assertEqual(decorated, 0, "a secret link is no item")
    assertNil(usedLine(tip), "a secret link is no item")
    M.ItemRefTooltip:SetInventoryItem("player", 5)
    postCall(M, M.ItemRefTooltip)
    -- red under: dropping the tooltip-identity gate from wanted().
    assertNil(usedLine(M.ItemRefTooltip), "not ItemRefTooltip")
    tip:SetInventoryItem("player", 5)
    postCall(M)
    assertTrue(usedLine(tip) ~= nil, "standing up, row on: the chest gets its line")
end)

test("tooltips: the post-call and the hooks are installed once, however often the addon stands up", function()
    local NS, M = scene()
    NS.Tooltips.Resume()
    NS.Compare.Resume()
    NS.ApplyEnabled(false)
    NS.ApplyEnabled(true)
    assertEqual(#M.__tooltipPostCalls[M.Enum.TooltipDataType.Item], 1)
    local hooks = 0
    for _, h in ipairs(M.__hooks) do if h.name == "GameTooltip_ShowCompareItem" then hooks = hooks + 1 end end
    assertEqual(hooks, 1)
end)

-- ── the compare tooltips ──────────────────────────────────────────────────────────────────────

local HEAD_ID = 219000

-- A made-up helm record (a link the mock has no entry for: its tooltip draws no lines of its own).
local function helm(n, quality, level)
    local id = HEAD_ID + n
    return { id = id, invType = "INVTYPE_HEAD", quality = quality, level = level, name = "Helm " .. n,
             link = ("|cff0070dd|Hitem:%d::::::::80:::::::::|h[Helm %d]|h|r"):format(id, n) }
end

local function compareScene()
    local NS, M = scene()
    M.__world:setCompare(true, true)
    return NS, M
end

local function showCompare(M, link)
    M.GameTooltip:SetHyperlink(link)
    M.GameTooltip:Show()
    M.GameTooltip_ShowCompareItem(M.GameTooltip)
end

-- Our compare tooltips that are shown, in index order.
local function shownCompares(M)
    local out = {}
    for i = 1, 10 do
        local tip = M["OutfitterRebornCompareTooltip" .. i]
        if tip and tip:IsShown() then out[#out + 1] = tip end
    end
    return out
end

test("compare: up to five tooltips, by level, quality 2 and up, ignoreComparisons and duplicates skipped", function()
    local NS, M = compareScene()
    local O = NS.Outfits
    for n = 1, 6 do O.Create("Set " .. n, { HeadSlot = helm(n, 3, 600 + n) }) end
    O.Create("Gray", { HeadSlot = helm(7, 1, 700) })
    local skip = O.Create("Skip", { HeadSlot = helm(8, 4, 710) })
    O.SetFlag(skip, "ignoreComparisons", true)
    O.Create("Same", { HeadSlot = snap(NS, "head_plate") })
    O.Create("Dupe", { HeadSlot = helm(6, 3, 606) })
    showCompare(M, DB.head_plate.link)
    local tips = shownCompares(M)
    -- red under: MAX above 5, or no cap at all (six candidates remain).
    assertEqual(#tips, 5, "five at most")
    -- red under: sorting ascending, or not sorting (store order would start at Set 1).
    local want = { "Set 6", "Set 5", "Set 4", "Set 3", "Set 2" }
    for i, tip in ipairs(tips) do
        assertEqual(tip.TextLeft1:GetText(), want[i], "line 1 of tooltip " .. i)
        assertEqual(tip.TextRight1:GetText(), "Outfitter")
    end
    local r, g, b = tips[1].TextLeft1:GetTextColor()
    local mr, mg, mb = NS.SkinColor("text.muted")
    assertEqual(("%.2f %.2f %.2f"):format(r, g, b), ("%.2f %.2f %.2f"):format(mr, mg, mb), "line 1 is muted")
    for _, tip in ipairs(tips) do
        local name = tip.TextLeft1:GetText()
        assertTrue(name ~= "Gray" and name ~= "Skip" and name ~= "Same" and name ~= "Dupe", name)
    end
end)

test("compare: the gates: stood down, the row, the client's wish, the modifier, a plain link, armor", function()
    local NS, M = compareScene()
    NS.Outfits.Create("Set", { HeadSlot = helm(1, 3, 600), MainHandSlot = snap(NS, "sword_1h_b") })
    showCompare(M, DB.head_plate.link)
    assertEqual(#shownCompares(M), 1, "the baseline shows one")
    M.__world:setCompare(true, false)
    M.GameTooltip_ShowCompareItem(M.GameTooltip)
    -- red under: dropping the COMPAREITEMS hide.
    assertEqual(#shownCompares(M), 0, "the modifier released hides them")
    M.__world:setCompare(false, true)
    showCompare(M, DB.head_plate.link)
    -- red under: dropping clientWantsCompare() from the gates.
    assertEqual(#shownCompares(M), 0, "the client wants no comparison")
    M.__world:setCompare(true, true)
    NS.db.profile.tooltip.compare = false
    showCompare(M, DB.head_plate.link)
    -- red under: dropping the tooltip.compare read.
    assertEqual(#shownCompares(M), 0, "the row is off")
    NS.db.profile.tooltip.compare = true
    NS.ApplyEnabled(false)
    showCompare(M, DB.head_plate.link)
    -- red under: dropping the NS.IsStoodDown() gate from Compare.OnShowCompare.
    assertEqual(#shownCompares(M), 0, "stood down")
    NS.ApplyEnabled(true)
    showCompare(M, DB.sword_1h.link)
    -- red under: dropping the armor-only check.
    assertEqual(#shownCompares(M), 0, "a weapon is not compared")
    local Info, parsed = NS.ItemInfo, 0
    local fromLink = Info.FromLink
    Info.FromLink = function(...) parsed = parsed + 1; return fromLink(...) end
    showCompare(M, DB.head_plate.link)   -- drawn plain, then the client hands the link out secret
    assertEqual(#shownCompares(M), 1, "the plain link compares")
    parsed = 0
    rawset(M.GameTooltip, "__item", T.secret(DB.head_plate.link))
    M.GameTooltip_ShowCompareItem(M.GameTooltip)
    Info.FromLink = fromLink
    -- red under: Compare.Show without its Secrets.PlainString (the secret link reaches FromLink).
    assertEqual(parsed, 0, "a secret link is never parsed")
    assertEqual(#shownCompares(M), 0, "a secret link is not compared")
end)

test("compare: releasing the modifier over the same item hides ours on the next frame", function()
    local NS, M = compareScene()
    NS.Outfits.Create("Set", { HeadSlot = helm(1, 3, 600) })
    showCompare(M, DB.head_plate.link)
    assertEqual(#shownCompares(M), 1, "the baseline shows one")
    M.OutfitterRebornCompareTooltip1:__fire("OnUpdate", 0.01)
    assertEqual(#shownCompares(M), 1, "held: still shown")
    M.__world:setCompare(false, false)   -- the client's ShouldDoItemComparison follows the modifier
    M.OutfitterRebornCompareTooltip1:__fire("OnUpdate", 0.01)
    -- red under: no OnUpdate hook on the first compare tooltip (they stay up until GameTooltip hides).
    assertEqual(#shownCompares(M), 0, "released: hidden")
end)

test("compare: placed beside the shopping tooltips, left to right on secret geometry", function()
    local NS, M = compareScene()
    local C, GT = NS.Compare, M.GameTooltip
    rawset(GT, "GetLeft", function() return 1500 end)
    rawset(GT, "GetRight", function() return 1800 end)
    local anchor, toRight = C.Placement()
    assertEqual(anchor, GT, "no shopping tooltip shown: beside GameTooltip")
    assertFalse(toRight, "more room on the left")
    M.ShoppingTooltip1:Show()
    M.ShoppingTooltip2:Show()
    -- red under: anchoring to ShoppingTooltip1 (the stock pair's inner tooltip) or to GameTooltip.
    assertEqual((C.Placement()), M.ShoppingTooltip2, "beside ShoppingTooltip2")
    M.ShoppingTooltip2:Hide()
    assertEqual((C.Placement()), M.ShoppingTooltip1, "beside ShoppingTooltip1 when it is alone")
    M.ShoppingTooltip1:Hide()
    rawset(GT, "GetLeft", function() return T.secret(1500) end)
    toRight = select(2, C.Placement())
    -- red under: answering right to left on unreadable geometry.
    assertTrue(toRight, "secret geometry: left to right")
end)

test("compare: GameTooltip's OnHide, Refresh and the stand-down hide every compare tooltip", function()
    local NS, M = compareScene()
    NS.Outfits.Create("Set", { HeadSlot = helm(1, 3, 600) })
    showCompare(M, DB.head_plate.link)
    assertEqual(#shownCompares(M), 1)
    M.GameTooltip:__fire("OnHide")
    -- red under: no OnHide hook on GameTooltip.
    assertEqual(#shownCompares(M), 0, "OnHide")
    showCompare(M, DB.head_plate.link)
    NS.Compare.Refresh()
    assertEqual(#shownCompares(M), 0, "Refresh")
    showCompare(M, DB.head_plate.link)
    NS.ApplyEnabled(false)
    -- red under: an empty Compare.Suspend.
    assertEqual(#shownCompares(M), 0, "stand-down")
end)

-- ── the outfit tooltip ────────────────────────────────────────────────────────────────────────

local function triggers(NS, desc)
    return T.fake(NS, "Triggers", { Get = function(id) return id == "SWIMMING" and { desc = desc } or nil end })
end

test("outfit tooltip: the name, the trigger description, Missing: in red and Banked: in blue", function()
    local NS, M = scene("bank_closed")
    openBank(NS, M)
    triggers(NS, "Worn while you are swimming")
    local id = outfit(NS, "Dive", { HeadSlot = "head_plate", LegsSlot = "legs_plate", NeckSlot = "neck_chain" })
    NS.Outfits.Get(id).trigger = { id = "SWIMMING" }
    local owner = M.CreateFrame("Button", nil, M.UIParent)
    assertTrue(NS.OutfitTooltip.Show(id, owner, "ANCHOR_RIGHT"))
    local tip = M.GameTooltip
    local lines = texts(tip)
    assertEqual(lines[1], "Dive")
    assertEqual(lines[2], "Worn while you are swimming")
    assertTrue(lines[3]:find("Missing:", 1, true) ~= nil and lines[3]:find(DB.neck_chain.name, 1, true) ~= nil, lines[3])
    assertTrue(lines[4]:find("Banked:", 1, true) ~= nil and lines[4]:find(DB.legs_plate.name, 1, true) ~= nil, lines[4])
    local r, g, b = tip.TextLeft4:GetTextColor()
    -- red under: the legacy red banked line.
    assertEqual(("%.2f %.2f %.2f"):format(r, g, b), "0.25 0.20 1.00", "the banked line is blue")
    assertTrue(lines[4]:find("|cff4033ff", 1, true) ~= nil, lines[4])
    r, g, b = tip.TextLeft3:GetTextColor()
    local mr, mg, mb = NS.SkinColor("of.outfit.missing")
    assertEqual(("%.2f %.2f %.2f"):format(r, g, b), ("%.2f %.2f %.2f"):format(mr, mg, mb), "missing is red")
    assertEqual(tip:GetOwner(), owner)
end)

test("outfit tooltip: nothing missing falls back to the newbie tip, which follows UberTooltips", function()
    local NS, M = scene()
    triggers(NS, "Worn while you are swimming")
    local id = outfit(NS, "Dive", { HeadSlot = "head_plate" })
    NS.Outfits.Get(id).trigger = { id = "SWIMMING" }
    local owner = M.CreateFrame("Button", nil, M.UIParent)
    M.__cvars.UberTooltips = "1"
    assertTrue(NS.OutfitTooltip.Show(id, owner))
    local lines = texts(M.GameTooltip)
    assertEqual(#lines, 2)
    assertEqual(lines[2], "Worn while you are swimming")
    M.GameTooltip:ClearLines()
    M.__cvars.UberTooltips = "0"
    -- red under: ignoring the CVar (the tip shows with UberTooltips off).
    assertFalse(NS.OutfitTooltip.Show(id, owner), "no newbie tips: nothing shows")
    -- red under: dropping the unknown-record return (Show raises on a nil record).
    assertFalse(NS.OutfitTooltip.Show("o999", owner), "an unknown outfit")
    local plain = outfit(NS, "Plain", { HeadSlot = "head_plate" })
    M.__cvars.UberTooltips = "1"
    -- red under: drawing the full tooltip whatever is missing (the `#missing > 0 or #banked > 0` test gone).
    assertFalse(NS.OutfitTooltip.Show(plain, owner), "nothing to say")
end)

test("outfit tooltip: `always` (the bar) draws the full tooltip with nothing missing, UberTooltips off", function()
    local NS, M = scene()
    triggers(NS, "Worn while you are swimming")
    local owner = M.CreateFrame("Button", nil, M.UIParent)
    M.__cvars.UberTooltips = "0"
    local plain = outfit(NS, "Plain", { HeadSlot = "head_plate" })
    -- red under: OT.Show ignoring `always` (the legacy pShowEmptyTooltips, OutfitterBar.lua:844).
    assertTrue(NS.OutfitTooltip.Show(plain, owner, "ANCHOR_RIGHT", true))
    local lines = texts(M.GameTooltip)
    assertEqual(#lines, 1)
    assertEqual(lines[1], "Plain")
    local id = outfit(NS, "Dive", { HeadSlot = "head_plate" })
    NS.Outfits.Get(id).trigger = { id = "SWIMMING" }
    assertTrue(NS.OutfitTooltip.Show(id, owner, "ANCHOR_RIGHT", true))
    lines = texts(M.GameTooltip)
    assertEqual(lines[1] .. "|" .. lines[2], "Dive|Worn while you are swimming")
end)
