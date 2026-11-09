-- tests/test_rows_secure.lua — P4.19 (design §7.3, INV §7.2, §16.3): modules/Window_Rows.lua's
-- fixed, virtualized rows and the secure child each one owns.
--
-- THE CONSTRAINT UNDER TEST (Outfitter.lua:8452-8462): a protected frame takes the one anchor it was
-- born with, so the secure child is SetAllPoints'd at birth and never SetPoint'd or SetParent'd after;
-- arming and disarming are no-ops in combat lockdown; a row is disarmed before it goes blank.
-- tests/mock_world.lua makes a Secure* frame protected: in lockdown its Show, Hide, SetAttribute and
-- the rest are refused and recorded in M.__blocked.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dock_scene.lua")(T)

local function rows(NS) return NS.WindowRows.rows end

-- The window open on the sheet, with outfits and loose items enough to fill more than 14 rows.
local function opened(scenario)
    local NS, M, fakes = scene({ scenario = scenario })
    for i = 1, 12 do NS.Outfits.Create(("Outfit %02d"):format(i), { HeadSlot = { id = 0 } }) end
    M.__world:openCharacter()
    NS.Dock.Open()
    return NS, M, fakes
end

-- The first row showing an entry of `kind` (and, for a category, of `id`).
local function rowOf(NS, kind, id)
    for _, row in ipairs(rows(NS)) do
        local e = row.entry
        if e and e.kind == kind and (id == nil or e.id == id) then return row end
    end
    return nil
end

local function secureFrames(M)
    local out = {}
    for name, f in pairs(M.__frameByName) do
        if name:find("^OutfitterRebornListRow%d+Secure$") then out[#out + 1] = f end
    end
    return out
end

test("rows: NS.WindowRows is published with the secure surface", function()
    local R = T.NS.WindowRows
    assertEqual(type(R), "table")
    for _, k in ipairs({ "Build", "Bind", "ArmSecure", "Disarm", "DisarmSecure", "Relevel", "OnClick", "PreClick" }) do
        assertEqual(type(R[k]), "function", k)
    end
    assertEqual(R.COUNT, 14); assertEqual(R.ROW_H, 18)
end)

test("rows: fourteen rows and their secure children are created once, each SetAllPoints'd at birth", function()
    local NS, M = opened()
    local secure = secureFrames(M)
    assertEqual(#secure, 14)
    for i, row in ipairs(rows(NS)) do
        assertEqual(row, M["OutfitterRebornListRow" .. i])
        local s = M["OutfitterRebornListRow" .. i .. "Secure"]
        assertEqual(row.secure, s)
        assertEqual(s.__template, "SecureActionButtonTemplate")
        assertEqual(s:GetParent(), row)
        assertEqual(#s.__pts, 0, "the secure child takes no SetPoint, only its birth SetAllPoints")
    end
    local first = rows(NS)[1]
    -- red under: drop the `Rows.built` early return in Rows.Build (a second build makes 14 more).
    NS.WindowRows.Build(NS.Window.Frame())
    NS.Dock.Close(); NS.Dock.Open()
    assertEqual(rows(NS)[1], first, "the rows were built again")
    assertEqual(#rows(NS), 14)
end)

test("rows: after build no SetPoint or SetParent reaches a secure child (quirk 3)", function()
    local NS, M = opened()
    local count = 0
    for _, s in ipairs(secureFrames(M)) do
        local setPoint, setParent, setAll, clear = s.SetPoint, s.SetParent, s.SetAllPoints, s.ClearAllPoints
        rawset(s, "SetPoint", function(...) count = count + 1; return setPoint(...) end)
        rawset(s, "SetParent", function(...) count = count + 1; return setParent(...) end)
        rawset(s, "SetAllPoints", function(...) count = count + 1; return setAll(...) end)
        rawset(s, "ClearAllPoints", function(...) count = count + 1; return clear(...) end)
    end
    -- Scroll, collapse, re-render, re-level, and move the sheet: everything the window does.
    NS.Window.SetOffset(3); NS.Window.SetOffset(0)
    NS.Window.ToggleCollapsed("Complete"); NS.Window.ToggleCollapsed("Complete")
    NS.Window.MarkDirty(true); NS.Window.Render()
    NS.Window.Relevel(10)
    rawset(M.CharacterFrame, "GetRight", function() return 400 end)
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 1)
    M.__world:closeCharacter(); M.__world:openCharacter(); NS.Dock.Open()
    assertEqual(count, 0, "a secure child was re-anchored or re-parented")
end)

test("rows: an item row arms its secure child with the bag and slot; other kinds hide it", function()
    local NS = opened()
    local armed, hidden, bagged = 0, 0, 0
    -- Every shown row, on every page: the first page holds no item row, so one page proves nothing.
    local function check()
        for _, row in ipairs(rows(NS)) do
            local e = row.entry
            if e and e.kind == "item" then
                armed = armed + 1
                local loc = e.item.loc or {}
                if loc.bag ~= nil then bagged = bagged + 1 end
                -- red under: Rows.ArmSecure without its s:Show() (the targeting click has no frame).
                assertTrue(row.secure:IsShown(), "an item row's secure child is shown")
                assertNil(row.secure:GetAttribute("type"))
                -- red under: Rows.ArmSecure dropping its target-bag / target-slot writes (INV §16.3).
                assertEqual(row.secure:GetAttribute("target-bag"), loc.bag)
                assertEqual(row.secure:GetAttribute("target-slot"), loc.slot)
            else
                hidden = hidden + 1
                -- red under: Rows.Bind without its Rows.Disarm first (a row scrolled from an item to
                -- another kind keeps its armed secure child; the SetOffset(0) pass below sees it).
                assertFalse(row.secure:IsShown(), "a non-item row's secure child is hidden")
            end
        end
    end
    check()
    assertTrue(hidden > 0, "the fixture shows no category or outfit row")
    NS.Window.SetOffset(#NS.Window.entries)
    check()
    assertTrue(armed > 0, "the fixture never showed an item row")
    NS.Window.SetOffset(0)                               -- the rows that held items now hold other kinds
    check()
    assertTrue(bagged > 0, "no item row on a bag slot: the attributes were never compared to a real one")
end)

test("rows: arm and disarm are no-ops in combat lockdown", function()
    local NS, M = opened()
    NS.Window.SetOffset(#NS.Window.entries)
    local before = #M.__blocked
    M.__lockdown = true
    NS.WindowRows.DisarmSecure()
    for _, row in ipairs(rows(NS)) do NS.WindowRows.ArmSecure(row) end
    -- red under: drop the `if locked() then return end` from Rows.Disarm (each Hide is refused and
    -- recorded in M.__blocked).
    assertEqual(#M.__blocked, before, "a protected call was attempted in lockdown")
    M.__lockdown = false
end)

test("rows: a row is disarmed BEFORE it goes blank", function()
    local NS = opened()
    NS.Window.SetOffset(#NS.Window.entries)
    local last = rows(NS)[NS.WindowRows.COUNT]
    local seen = {}
    for _, row in ipairs(rows(NS)) do
        local hide = row.secure.Hide
        rawset(row.secure, "Hide", function(self, ...)
            seen[#seen + 1] = { row = row, entry = row.entry }
            return hide(self, ...)
        end)
    end
    assertTrue(last.entry ~= nil, "the last row is not filled")
    -- Collapse every section: the bottom rows go blank.
    for _, id in ipairs({ "Complete", "Accessory", "unused", "warbound", "boe" }) do
        NS.Window.collapsed[id] = true
    end
    NS.Window.SetOffset(0); NS.Window.Render()
    assertNil(last.entry, "the last row did not go blank")
    local hiddenWhileFilled = false
    for _, s in ipairs(seen) do
        if s.row == last and s.entry ~= nil then hiddenWhileFilled = true end
    end
    -- red under: set `row.entry = entry` before `Rows.Disarm(row)` in Rows.Bind.
    assertTrue(hiddenWhileFilled, "the row's secure child was not hidden while it still held its entry")
    assertFalse(last.secure:IsShown())
end)

test("rows: PLAYER_REGEN_DISABLED disarms every row while protected calls are still allowed", function()
    local NS, M = opened()
    NS.Window.SetOffset(#NS.Window.entries)
    local anyArmed = false
    for _, row in ipairs(rows(NS)) do anyArmed = anyArmed or row.secure:IsShown() end
    assertTrue(anyArmed, "no row was armed before combat")
    M.__fire("PLAYER_REGEN_DISABLED")
    M.__lockdown = true
    for _, row in ipairs(rows(NS)) do assertFalse(row.secure:IsShown()) end
    M.__lockdown = false
end)

test("rows: a click while a spell targets an item is the secure button's, not the row's", function()
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    local wears = 0
    local wear = NS.Stack.Wear
    NS.Stack.Wear = function(...) wears = wears + 1; return wear(...) end
    rawset(M, "SpellCanTargetItem", function() return true end)
    row:__fire("PreClick", "LeftButton")
    row:__fire("PostClick", "LeftButton")
    -- red under: skip the `row.usingSpell` early return in Rows.OnClick.
    assertEqual(wears, 0, "the row acted on a spell-targeting click")
    M.SpellCanTargetItem = nil
    row:__fire("PreClick", "LeftButton")
    row:__fire("PostClick", "LeftButton")
    assertEqual(wears, 1)
    NS.Stack.Wear = wear
end)

test("rows: outfit clicks wear, open the menu, and the worn box wears and removes", function()
    local NS, _, fakes = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    row:__fire("PostClick", "LeftButton")
    assertTrue(NS.Stack.IsWorn(id))
    row:__fire("PostClick", "RightButton")
    assertEqual(fakes.OutfitMenu.__count("Open"), 1)
    assertEqual(fakes.OutfitMenu.__calls[1][2], row); assertEqual(fakes.OutfitMenu.__calls[1][3], id)
    row.menu:__fire("OnClick", "LeftButton")
    assertEqual(fakes.OutfitMenu.__count("Open"), 2)
    row.worn:SetChecked(false); row.worn:__fire("OnClick")
    assertFalse(NS.Stack.IsWorn(id))
    row.worn:SetChecked(true); row.worn:__fire("OnClick")
    assertTrue(NS.Stack.IsWorn(id))
end)

test("rows: a category click collapses it for the session", function()
    local NS = opened()
    local row = rowOf(NS, "category", "Accessory")
    row:__fire("PostClick", "LeftButton")
    assertTrue(NS.Window.collapsed.Accessory)
    -- red under: build the outfit rows of a collapsed category anyway (Window_ListModel.Build).
    assertNil(rowOf(NS, "outfit"), "the outfits under it are gone")
    row:__fire("PostClick", "LeftButton")
    assertNil(NS.Window.collapsed.Accessory)
end)

test("rows: an item right-click uses it, except on the merchant's buyback tab", function()
    local NS, M = opened()
    NS.Window.SetOffset(#NS.Window.entries)
    local row
    for _, r in ipairs(rows(NS)) do if r.entry and r.entry.kind == "item" then row = r end end
    assertTrue(row ~= nil, "no item row")
    local used = {}
    local use = NS.Compat.UseContainerItem
    NS.Compat.UseContainerItem = function(bag, slot) used[#used + 1] = { bag, slot } end
    local merchant = M.CreateFrame("Frame", "MerchantFrame", M.UIParent)
    merchant.selectedTab = 2
    row.secure:__fire("PostClick", "RightButton")
    -- red under: drop the buyback-tab test from the item click.
    assertEqual(#used, 0, "an item was sold from the buyback tab")
    merchant.selectedTab = 1
    row.secure:__fire("PostClick", "RightButton")
    assertEqual(#used, 1)
    assertEqual(used[1][1], row.entry.item.loc.bag)
    NS.Compat.UseContainerItem = use
end)

-- ── the outfit row's layout (sheet and window feedback design G4, plan Task 3.4) ──────────────────

-- The last point a frame (recorded `__pts`) or a texture (GetPoint) was given.
local function lastPoint(obj)
    local pts = rawget(obj, "__pts")
    if pts then return pts[#pts] or {} end
    return { obj:GetPoint(1) }
end

local function assertLeftAt(row, obj, x, what)
    local p = lastPoint(obj)
    assertEqual(p[1], "LEFT", what); assertEqual(p[2], row, what); assertEqual(p[3], "LEFT", what)
    assertEqual(p[4], x, what)
end

-- Click a row's Equipment Manager mark.
local function clickEM(row) row.em:__fire("OnClick", "LeftButton") end

test("rows: an outfit row shows worn, icon, EM mark, name in that order", function()
    -- G4: [worn] [outfit icon] [Equipment Manager icon] [name] ... [automation] [gear].
    -- red under: the outfit icon left unbuilt, or the EM mark and the name still at 32 and 50.
    local NS = opened()
    local row = rowOf(NS, "outfit")
    assertLeftAt(row, row.worn, 14, "the worn box")
    assertLeftAt(row, row.outfitIcon, 32, "the outfit icon")
    assertLeftAt(row, row.em, 50, "the EM mark")
    assertLeftAt(row, row.name, 68, "the name")
    assertEqual(select(4, row.name:GetPoint(2)), -38, "the name ends clear of the lightning")
    assertEqual(row.outfitIcon:GetWidth(), 16)
    -- The default (a fileID, smoke round 2 design G1) draws on the edged art texture at the same place.
    assertTrue(row.outfitArt:IsShown(), "an outfit row shows its icon")
    assertLeftAt(row, row.outfitArt, 32, "the outfit art")
    -- The one resolver the bar and the broker draw too (plan Task 3.5), its tint included: a tinted
    -- glyph, so the tint is not the default's white.
    -- red under: the row keeping the bar's interim, untinted answer.
    local id = row.entry.id
    assertTrue(NS.Outfits.SetIcon(id, assert(NS.Icon("ph:sword")), "ff8000"))
    NS.Window.MarkDirty(true); NS.Window.Render()
    for _, r in ipairs(rows(NS)) do if r.entry and r.entry.id == id then row = r end end
    assertTrue(row.outfitIcon:IsShown(), "an outfit row shows its glyph icon")
    local tex, r, g, b = NS.OutfitIcon(NS.Outfits.Get(id))
    assertEqual(row.outfitIcon:GetTexture(), tex)
    local vr, vg, vb = row.outfitIcon:GetVertexColor()
    assertTrue(vr == r and vg == g and vb == b, "the row draws the resolver's tint")
    -- tests/dock_scene.lua gives a CheckButton, and only a CheckButton, its own SetChecked.
    assertTrue(row.em.icon ~= nil and rawget(row.em, "SetChecked") == nil, "the EM mark is a button, not a box")
    -- An item row keeps its own icon where it was, and draws no outfit icon.
    NS.WindowRows.Bind(row, { kind = "item", item = { id = 1, name = "Hat", loc = {} } }, 1)
    assertLeftAt(row, row.icon, 14, "an item row's icon")
    assertTrue(row.icon:IsShown()); assertFalse(row.outfitIcon:IsShown(), "an item row drew the outfit icon")
    assertFalse(row.em:IsShown(), "an item row drew the EM mark")
end)

-- An outfit's icon is a fileID (Blizzard art, edged and zoom-cropped as an item's is; the default,
-- 132724, among them) or a catalog glyph, drawn whole and borderless.
test("rows: a glyph outfit icon is drawn uncropped; a fileID one edged and cropped", function()
    local NS = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    local function rebound()
        NS.Window.MarkDirty(true); NS.Window.Render()
        for _, r in ipairs(rows(NS)) do if r.entry and r.entry.id == id then row = r end end
    end
    -- Smoke round 2 design G1: the default is the fileID 132724, on the edged art texture.
    -- red under: the coat-hanger glyph default (drawn whole on outfitIcon).
    assertEqual((NS.OutfitIcon(NS.Outfits.Get(id))), 132724)
    assertTrue(row.outfitArt:IsShown(), "the default is not on the edged texture")
    assertEqual(row.outfitArt:GetTexture(), 132724)
    assertFalse(row.outfitIcon:IsShown(), "the default also drew the glyph texture")
    local l = row.outfitArt:GetTexCoord()
    assertTrue(math.abs(l - 0.07) < 1e-6, "the default is not zoom-cropped")
    local glyph = assert(NS.Icon("ph:sword"))
    assertTrue(NS.Outfits.SetIcon(id, glyph))
    rebound()
    assertEqual(row.outfitIcon:GetTexture(), glyph)
    -- red under: the glyph drawn through S.IconBorder (texcoords 0.07..0.93).
    assertEqual((row.outfitIcon:GetTexCoord()), 0, "the glyph is cropped")
    assertFalse(row.outfitArt:IsShown(), "a glyph outfit drew the edged art texture")
end)

test("rows: the EM mark is full for an EM outfit and dimmed otherwise", function()
    -- G4: the Equipment Manager tab's own icon, read from PAPERDOLL_SIDEBARS[3] at run time.
    -- red under: one alpha for both kinds, or a texture other than the tab's.
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    local tab = M.PAPERDOLL_SIDEBARS[3]
    assertEqual(row.em.icon:GetTexture(), tab.icon)
    assertEqual(table.concat({ row.em.icon:GetTexCoord() }, ","), table.concat({
        tab.texCoords[1], tab.texCoords[3], tab.texCoords[1], tab.texCoords[4],
        tab.texCoords[2], tab.texCoords[3], tab.texCoords[2], tab.texCoords[4] }, ","), "the tab's crop")
    assertTrue(row.em:IsShown())
    assertEqual(row.em:GetAlpha(), 0.35, "a native outfit's mark is dimmed")
    local isEM = NS.Outfits.IsEM
    NS.Outfits.IsEM = function(i) return i == id or isEM(i) end
    NS.Window.MarkDirty(true); NS.Window.Render()
    assertEqual(rowOf(NS, "outfit", id).em:GetAlpha(), 1, "an EM outfit's mark is full")
    NS.Outfits.IsEM = isEM
end)

test("rows: one click on the EM mark saves or removes the outfit through NS.EM.SetStored, selected or not", function()
    -- The owner's E12(2) ruling: no wear or select first; the gear menu's On/Off is the same call.
    local NS = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    local asked = {}
    local setStored = NS.EM.SetStored
    NS.EM.SetStored = function(i, on) asked[#asked + 1] = { i, on }; return true end
    NS.Stack.Select(nil)
    clickEM(row)
    -- red under: the INV §3.5 two-step (the first click on an unselected outfit only selected it).
    assertEqual(#asked, 1, "one click did not save")
    assertEqual(asked[1][1], id); assertTrue(asked[1][2] == true, "a dimmed mark's click is not a save")
    assertNil(NS.Stack.Selected(), "the click selected the outfit")
    -- The full mark (an EM outfit) removes it.
    local isEM = NS.Outfits.IsEM
    NS.Outfits.IsEM = function(i) return i == id or isEM(i) end
    clickEM(row)
    assertEqual(#asked, 2); assertTrue(asked[2][2] == false, "a full mark's click is not a remove")
    NS.Outfits.IsEM = isEM
    NS.EM.SetStored = setStored
end)

test("rows: the EM mark's tooltip states the true state and what a click does", function()
    -- E12(1)/(2): red under the old fixed text (an outfit not stored read "Stored in ...").
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    local tip = M.GameTooltip
    row.em:__fire("OnEnter")
    assertEqual(tip.TextLeft1:GetText(), "Not stored in the Equipment Manager")
    assertEqual(tip.TextLeft2:GetText(), "Click to save in the Equipment Manager")
    row.em:__fire("OnLeave")
    local isEM = NS.Outfits.IsEM
    NS.Outfits.IsEM = function(i) return i == id or isEM(i) end
    row.em:__fire("OnEnter")
    assertEqual(tip.TextLeft1:GetText(), "Stored in the Equipment Manager")
    assertEqual(tip.TextLeft2:GetText(), "Click to remove from the Equipment Manager")
    NS.Outfits.IsEM = isEM
end)

test("rows: clicking the EM mark in combat refuses and changes nothing", function()
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    local calls = 0
    local store, keep = NS.EM.StoreOnServer, NS.EM.StoreLocally
    NS.EM.StoreOnServer = function() calls = calls + 1; return true end
    NS.EM.StoreLocally = function() calls = calls + 1 end
    NS.Stack.Select(id)
    local alpha = row.em:GetAlpha()
    M.__lockdown = true
    M.__resetPrinted()
    clickEM(row)
    M.__lockdown = false
    -- red under: drop the combat refusal from NS.EM.SetStored (the click's one path).
    assertEqual(calls, 0, "an EM store ran in combat")
    assertEqual(row.em:GetAlpha(), alpha, "the mark changed in combat")
    assertTrue(table.concat(M.__printed(), "\n"):find("Outfits can't be changed in combat.", 1, true) ~= nil)
    NS.EM.StoreOnServer, NS.EM.StoreLocally = store, keep
end)

test("rows: the menu control is a borderless gear that opens the outfit menu", function()
    -- G4: the gear replaces the ... button. red under: NS.Icon("ellipses"), or S.Button(menu) boxed.
    -- Forever smoke feedback S6: painted as the title gear is, S.CloseButton (rest, hot under the pointer).
    local NS, M, fakes = opened()
    local row = rowOf(NS, "outfit")
    local menu = row.menu
    assertEqual(menu.icon:GetTexture(), NS.Icon("ph:gear-six"))
    local p = lastPoint(menu)
    assertEqual(p[1], "RIGHT"); assertEqual(p[2], row); assertEqual(p[3], "RIGHT"); assertEqual(p[4], -4)
    local rec = M.LibStub("LibKa0s-Skin-1.0").painted[menu]
    assertTrue(rec ~= nil and rec.calls.CloseButton ~= nil, "S.CloseButton(menu)")
    assertTrue(rec.calls.Button == nil, "no boxed S.Button on the gear")
    menu:__fire("OnClick", "LeftButton")
    assertEqual(fakes.OutfitMenu.__count("Open"), 1)
    assertEqual(fakes.OutfitMenu.__calls[1][2], menu); assertEqual(fakes.OutfitMenu.__calls[1][3], row.entry.id)
end)

test("rows: the lightning has no border", function()
    -- G4/G10: the automation mark is a tinted glyph, never boxed or edged. red under:
    -- S.IconBorder(row.trig) or a Button in its place.
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    assertEqual(row.trig:GetObjectType(), "Texture")
    local calls = M.LibStub("LibKa0s-Skin-1.0").painted[row.trig].calls
    assertTrue(calls.Mark ~= nil, "the lightning is an S.Mark")
    assertTrue(calls.IconBorder == nil, "the lightning is edged")
    local p = { row.trig:GetPoint(1) }
    assertEqual(p[1], "RIGHT"); assertEqual(p[4], -22); assertEqual(row.trig:GetWidth(), 12)
end)

test("rows: an outfit row's name is colored by its status, and a disabled one says so", function()
    local NS = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    local painted = {}
    local text = NS.Skin.Text
    NS.Skin.Text = function(fs, role, ...) painted[fs] = role; return text(fs, role, ...) end
    NS.Outfits.Get(id).trigger = { id = "IN_DUNGEON", disabled = true }
    NS.Window.MarkDirty(true); NS.Window.Render()
    row = rowOf(NS, "outfit")
    assertEqual(row.entry.id, id)
    assertEqual(painted[row.name], "of.outfit.disabled")
    assertEqual(row.name:GetText(), NS.Outfits.Get(id).name .. " (Disabled)")
    assertTrue(row.trig:IsShown(), "an outfit with a trigger shows the mark")
    assertEqual(row.trig:GetAlpha(), 0.4)
    NS.Skin.Text = text
end)

test("rows: a profile switch redraws the trigger mark from the new profile's auto.enabled", function()
    local NS = opened()
    local id = rowOf(NS, "outfit").entry.id
    NS.Outfits.Get(id).trigger = { id = "IN_DUNGEON" }
    NS.db:SetProfile("Alt")
    assertTrue(NS.SetByPath("auto.enabled", false))
    NS.db:SetProfile("Default")
    NS.Window.MarkDirty(true); NS.Window.Render()
    assertEqual(rowOf(NS, "outfit", id).trig:GetAlpha(), 1, "Default has automatic changes on")
    -- A switch writes no row, so no SETTINGS_CHANGED reaches the window: the dock's next follow tick
    -- draws only what marked the list dirty.
    NS.db:SetProfile("Alt")
    NS.Window.RenderIfDirty()
    -- red under: no PROFILE_CHANGED receiver in Win.Install (modules/Window.lua).
    assertEqual(rowOf(NS, "outfit", id).trig:GetAlpha(), 0.4, "the mark kept the old profile's auto.enabled")
    NS.db:SetProfile("Default")
    NS.Window.RenderIfDirty()
    assertEqual(rowOf(NS, "outfit", id).trig:GetAlpha(), 1, "the switch back left the mark dimmed")
end)

test("rows: an item with no quality color is drawn muted, never in the previous item's color", function()
    local NS = opened()
    local row = rows(NS)[1]
    NS.WindowRows.Bind(row, { kind = "item", item = { id = 1, name = "Epic", quality = 4, loc = {} } }, 1)
    local er, eg, eb = NS.QualityColor(4)
    local r, g, b = row.itemName:GetTextColor()
    assertEqual(("%s,%s,%s"):format(r, g, b), ("%s,%s,%s"):format(er, eg, eb), "the epic color")
    NS.WindowRows.Bind(row, { kind = "item", item = { id = 2, name = "Uncached", loc = {} } }, 1)
    local mr, mg, mb = NS.SkinColor("text.muted")
    r, g, b = row.itemName:GetTextColor()
    -- red under: RENDER.item setting the color only when NS.QualityColor answers one.
    assertEqual(("%s,%s,%s"):format(r, g, b), ("%s,%s,%s"):format(mr, mg, mb), "no quality: muted")
end)

-- ── hover (Forever smoke feedback S6) ────────────────────────────────────────────────────────────

-- Record the state each ListRow paint gave a row.
local function rowStates(NS)
    local seen = {}
    local paint = NS.Skin.ListRow
    NS.Skin.ListRow = function(row, state, ...)
        seen[row] = state
        return paint(row, state, ...)
    end
    return seen
end

test("rows: a row wears the hover wash while the pointer is over it or its controls", function()
    local NS = opened()
    local seen = rowStates(NS)
    local row = rowOf(NS, "outfit")
    row:__fire("OnEnter")
    -- red under: a row with no hover state (Bind paints stripe and selection only).
    assertTrue(seen[row].hover, "the row's own enter")
    rawset(row, "IsMouseOver", function() return true end)
    row:__fire("OnLeave")
    row.worn:__fire("OnEnter")
    assertTrue(seen[row].hover, "onto the worn box the wash stays")
    row.worn:__fire("OnLeave")
    assertTrue(seen[row].hover, "back onto the row it stays")
    rawset(row, "IsMouseOver", function() return false end)
    row.menu:__fire("OnLeave")
    assertFalse(seen[row].hover, "off the row it goes")
end)

test("rows: a blank row takes no hover, and a rebind keeps the stripe and selection", function()
    local NS = opened()
    local seen = rowStates(NS)
    local rs = rows(NS)
    local blank
    for _, row in ipairs(rs) do if not row.entry then blank = row end end
    if blank then
        blank:__fire("OnEnter")
        assertFalse(seen[blank] ~= nil and seen[blank].hover == true, "a blank row lit up")
    end
    local row = rowOf(NS, "outfit")
    row:__fire("OnEnter")
    assertEqual(seen[row].stripe, row.stripe, "the hover paint keeps the stripe")
end)

test("rows: the worn box and the EM mark wash in the skin's accent; the gear is painted as the title gear", function()
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    for _, ctl in ipairs({ row.worn, row.em }) do
        assertTrue(ctl.hot ~= nil, "a hover wash on " .. tostring(ctl:GetName()))
        ctl:__fire("OnEnter")
        local p = M.__paint(ctl.hot)
        local r, g, b = NS.SkinColor("icon.arrow")
        -- red under: no wash (the box's faint menu.hover, the mark's none).
        assertEqual(p.color and p.color[1], r); assertEqual(p.color[2], g); assertEqual(p.color[3], b)
        assertEqual(p.color[4], 0.35)
        assertEqual(p.layer, "HIGHLIGHT")
    end
    -- red under: NS.Skin.Button's noBg pass (no tint on the gear's art, so no hover color either).
    local title = M.__paint(M.OutfitterRebornWindowSettings.icon)
    local gear = M.__paint(row.menu.icon)
    assertTrue(gear.vertex ~= nil, "the row gear's art is tinted")
    assertEqual(table.concat(gear.vertex, ","), table.concat(title.vertex or {}, ","), "as the title gear's is")
end)

test("window: the footer's three buttons share the plain look; All and None dim their label (R2-3, R2-4)", function()
    local NS, M = opened()
    local skin = M.LibStub("LibKa0s-Skin-1.0").painted
    local new, all, none = M.OutfitterRebornNewOutfitButton, M.OutfitterRebornSlotsAll, M.OutfitterRebornSlotsNone
    assertEqual(new.text:GetText(), NS.L["New outfit"], "no ellipsis")
    local nopts = skin[new].calls.Button[1]
    -- red under: { primary = true } on New outfit (its fill made the label hard to read).
    assertTrue(type(nopts) ~= "table" or nopts.primary ~= true, "New outfit is a plain button")
    for _, b in ipairs({ all, none }) do
        local o = skin[b].calls.Button[1]
        assertEqual(o.tokens and o.tokens.text, "text.muted", "a dimmer label")
        assertTrue(o.primary ~= true)
    end
end)
