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
    assertTrue(row.outfitIcon:IsShown(), "an outfit row shows its icon")
    -- The interim resolver (plan Task 3.5 swaps it for NS.OutfitIcon): the bar's.
    assertEqual(row.outfitIcon:GetTexture(), NS.Bar.OutfitIcon(NS.Outfits.Get(row.entry.id)))
    -- tests/dock_scene.lua gives a CheckButton, and only a CheckButton, its own SetChecked.
    assertTrue(row.em.icon ~= nil and rawget(row.em, "SetChecked") == nil, "the EM mark is a button, not a box")
    -- An item row keeps its own icon where it was, and draws no outfit icon.
    NS.WindowRows.Bind(row, { kind = "item", item = { id = 1, name = "Hat", loc = {} } }, 1)
    assertLeftAt(row, row.icon, 14, "an item row's icon")
    assertTrue(row.icon:IsShown()); assertFalse(row.outfitIcon:IsShown(), "an item row drew the outfit icon")
    assertFalse(row.em:IsShown(), "an item row drew the EM mark")
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

test("rows: clicking the dimmed EM mark stores the outfit on the server, as the checkbox did", function()
    -- INV §3.5 OutfitServerButton: the first click on an outfit that is not selected only selects it;
    -- a click on the selected one stores it on the server, and a refusal shows the popup.
    local NS, M = opened()
    local row = rowOf(NS, "outfit")
    local id = row.entry.id
    local stored, local_ = {}, {}
    local store, keep = NS.EM.StoreOnServer, NS.EM.StoreLocally
    NS.EM.StoreOnServer = function(i) stored[#stored + 1] = i; return false, "OUTFITTERREBORN_EM_FULL" end
    NS.EM.StoreLocally = function(i) local_[#local_ + 1] = i end
    NS.Stack.Select(nil)
    clickEM(row)
    assertEqual(#stored, 0, "the first click only selects")
    assertEqual(NS.Stack.Selected(), id)
    clickEM(row)
    assertEqual(#stored, 1); assertEqual(stored[1], id)
    assertEqual(M.__popups[#M.__popups].which, "OUTFITTERREBORN_EM_FULL")
    assertEqual(#local_, 0, "a native outfit's click stored it locally")
    -- The full mark on an EM outfit stores it locally (the old uncheck).
    local isEM = NS.Outfits.IsEM
    NS.Outfits.IsEM = function(i) return i == id or isEM(i) end
    clickEM(row)
    assertEqual(#local_, 1); assertEqual(#stored, 1)
    NS.Outfits.IsEM = isEM
    NS.EM.StoreOnServer, NS.EM.StoreLocally = store, keep
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
    -- red under: drop the `locked()` refusal from the EM click.
    assertEqual(calls, 0, "an EM store ran in combat")
    assertEqual(row.em:GetAlpha(), alpha, "the mark changed in combat")
    assertTrue(table.concat(M.__printed(), "\n"):find("Outfits can't be changed in combat.", 1, true) ~= nil)
    NS.EM.StoreOnServer, NS.EM.StoreLocally = store, keep
end)

test("rows: the menu control is a borderless gear that opens the outfit menu", function()
    -- G4: the gear replaces the ... button. red under: NS.Icon("ellipses"), or S.Button(menu) boxed.
    local NS, M, fakes = opened()
    local row = rowOf(NS, "outfit")
    local menu = row.menu
    assertEqual(menu.icon:GetTexture(), NS.Icon("ph:gear-six"))
    local p = lastPoint(menu)
    assertEqual(p[1], "RIGHT"); assertEqual(p[2], row); assertEqual(p[3], "RIGHT"); assertEqual(p[4], -4)
    local rec = M.LibStub("LibKa0s-Skin-1.0").painted[menu]
    local opts = rec and rec.calls.Button and rec.calls.Button[1]
    assertTrue(type(opts) == "table" and opts.noBg == true and opts.noBorder == true, "S.Button(menu, { noBg, noBorder })")
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
