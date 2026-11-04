-- tests/test_preview.lua — P4.22 (design §8): test mode. modules/Preview.lua turns the outfit bar
-- over to defaults/PreviewOutfits.lua's five sample outfits under the amber strip; nothing is equipped
-- or saved; and the mode ends on its own switch, on combat (with one line), on Reset all and,
-- silently, on the stand-down, but not on re-locking the bar. The window lists the same samples
-- (smoke round 2 design G7, which reverses H17): the window section below.
--
-- Every module it touches has landed (Bar, PlayerState, Outfits, the window's list model) and runs for
-- real; only NS.OutfitMenu (P4.21) is absent, and a placeholder's right-click never reaches it.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- Name and own icon; Test Outfit 3 has none and is keyed as a seeded spec outfit, Test Outfit 5 has
-- none and draws the default.
local SAMPLES = {
    { "Test Outfit 1", 132276 }, { "Test Outfit 2", 1376041 }, { "Test Outfit 3", nil },
    { "Test Outfit 4", 132261 }, { "Test Outfit 5", nil },
}
local STRIP = "Test mode: sample outfits. Nothing is equipped or saved"
local REFUSED = "Test mode is not available in combat."
local ENDED = "Test mode ended: you entered combat."

--- A fresh instance on the geared scenario, the engine and the bar resumed, the paint recorder in.
--- `opts.shown` turns the bar on first.
local function scene(opts)
    opts = opts or {}
    local inst = T.load({ mutate = function(M) M.__gear:load("geared") end })
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Inventory.Resume()
    NS.Equip.Resume()
    M.__fireTimers()
    dofile(T.root .. "/tests/_kit/mock_paint.lua")(M)
    if opts.shown then NS.db.profile.bar.shown = true end
    NS.Bar.Resume()
    M.__fireTimers()
    return NS, M
end

local function settle(M) M.__fireTimers() end

local SLOTS = {
    "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "MainHandSlot", "SecondaryHandSlot", "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot",
    "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
}

--- A Complete outfit's items: every slot empty.
local function naked()
    local items = {}
    for _, s in ipairs(SLOTS) do items[s] = { id = 0 } end
    return items
end

local function printed(M, line)
    local n = 0
    for _, said in ipairs(M.__printed()) do
        if said:find(line, 1, true) then n = n + 1 end
    end
    return n
end

local function barShown(NS)
    local f = NS.Bar.Frame()
    return f ~= nil and f:IsShown() == true
end

local function stripShown(NS)
    local f = NS.Bar.Frame()
    return f ~= nil and f.strip ~= nil and f.strip ~= false and f.strip:IsShown() == true
end

--- A stable rendering of a table (sorted keys), for the before/after compare.
local function dump(v, seen)
    if type(v) ~= "table" then return type(v) .. ":" .. tostring(v) end
    seen = seen or {}
    if seen[v] then return "<cycle>" end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(v[k], seen) end
    seen[v] = nil
    return "{" .. table.concat(out, ",") .. "}"
end

local function snapshot(NS)
    return dump({ profile = NS.db.profile, char = NS.db.char, global = NS.db.global })
end

-- ── the surface and the placeholders ──────────────────────────────────────────────────────────

test("preview: NS.Preview publishes the §8 surface and starts off", function()
    local P = T.NS.Preview
    assertEqual(type(P), "table")
    for _, k in ipairs({ "Start", "Stop", "Toggle", "IsActive", "Suspend", "Resume", "Diagnose" }) do
        assertEqual(type(P[k]), "function", k)
    end
    assertEqual(type(P.Source.Rows), "function")
    assertFalse(P.IsActive())
    assertEqual(T.NS.State.testMode, false)
end)

test("preview: the placeholders are five Test Outfits in two rows, each stamped placeholder and preview:<n>", function()
    local NS = scene()
    local rows = NS.PreviewOutfits.Rows()
    assertEqual(#rows, 2)
    assertEqual(rows[1].categoryID, "Complete")
    assertEqual(rows[2].categoryID, "Accessory")
    local n = 0
    for _, row in ipairs(rows) do
        for _, rec in ipairs(row.outfits) do
            n = n + 1
            assertEqual(rec.name, SAMPLES[n][1])
            assertEqual(rec.icon, SAMPLES[n][2])
            assertTrue(rec.placeholder == true, "placeholder " .. n)
            -- red under: a stamp that numbers each row from 1 (preview:1..3, then preview:1..2)
            assertEqual(rec.id, "preview:" .. n)
        end
    end
    assertEqual(n, 5)
    -- Stamped once: a second read answers the same records.
    assertTrue(NS.PreviewOutfits.Rows()[1].outfits[1] == rows[1].outfits[1])
    -- No sample resolves in the store (C28; the id rule's own red is test_outfits').
    for i = 1, 5 do assertNil(NS.Outfits.Get("preview:" .. i), "preview:" .. i .. " in the store") end
end)

-- ── what it shows ─────────────────────────────────────────────────────────────────────────────

test("preview: Start fills the bar with the five sample outfits, real icons and the localized strip", function()
    local NS, M = scene()
    NS.Outfits.Create("Real", naked())
    settle(M)
    assertFalse(barShown(NS), "the bar starts off")
    assertTrue(NS.Preview.Start())
    settle(M)
    assertTrue(NS.Preview.IsActive())
    assertEqual(NS.State.testMode, true)
    assertTrue(barShown(NS), "test mode shows the bar even with bar.shown off")
    local names, icons = {}, {}
    for _, btn in ipairs(NS.Bar.Buttons()) do
        names[#names + 1] = btn.outfit.name
        icons[#icons + 1] = btn.icon:GetTexture()
    end
    -- red under: a Source that answers Bar.LiveSource's rows
    assertEqual(table.concat(names, ","), "Test Outfit 1,Test Outfit 2,Test Outfit 3,Test Outfit 4,Test Outfit 5")
    local spec = NS.Triggers.Get("SPEC_1").icon
    assertTrue(type(spec) == "number" and spec ~= NS.Constants.DEFAULT_OUTFIT_ICON, "the mock has a spec icon")
    -- red under: a Test Outfit 3 that is not keyed SPEC_1 (it would draw the default)
    assertEqual(table.concat(icons, ","), "132276,1376041," .. spec .. ",132261," .. NS.Constants.DEFAULT_OUTFIT_ICON)
    assertTrue(stripShown(NS), "the strip is up")
    assertEqual(NS.Bar.Frame().strip.text:GetText(), STRIP)
end)

test("preview: the window lists the same samples as the bar, and the real outfits again after", function()
    local NS, M = scene()
    local real = NS.Outfits.Create("Real", naked())
    local function listed()
        local found, samples = false, 0
        for _, e in ipairs(NS.WindowListModel.Build({}, {})) do
            if e.id == real then found = true end
            if type(e.id) == "string" and e.id:find("^preview:") then samples = samples + 1 end
        end
        return found, samples
    end
    NS.Preview.Start()
    settle(M)
    local found, samples = listed()
    -- red under: a list model that ignores test mode (H17's real data)
    assertFalse(found, "the real outfit is in the test window's list")
    assertEqual(samples, 5)
    NS.Preview.Stop()
    settle(M)
    found, samples = listed()
    assertTrue(found, "the real outfit did not come back")
    assertEqual(samples, 0)
end)

test("preview: placeholders never equip and a whole session writes nothing to the saved data", function()
    local NS, M = scene()
    NS.Outfits.Create("Real", naked())
    settle(M)
    local before, calls = snapshot(NS), #M.__equipCalls
    NS.Preview.Start()
    settle(M)
    M.IsAltKeyDown = function() return false end
    for _, btn in ipairs(NS.Bar.Buttons()) do
        btn:__fire("OnClick", "LeftButton")
        btn:__fire("OnClick", "RightButton")
        btn:__fire("OnEnter")
        btn:__fire("OnLeave")
    end
    settle(M)
    NS.Preview.Toggle()
    settle(M)
    NS.Preview.Toggle()
    settle(M)
    NS.Preview.Stop()
    settle(M)
    assertEqual(#M.__equipCalls, calls, "a placeholder reached the equip path")
    assertEqual(#NS.db.char.stack, 0, "nothing worn")
    -- red under: a Start that persists the flag (NS.db.profile.state = { testMode = true }, say)
    assertEqual(snapshot(NS), before)
end)

-- ── refusals and ends ─────────────────────────────────────────────────────────────────────────

test("preview: refused in combat with the exact line, and silent while stood down", function()
    local NS, M = scene()
    M.InCombatLockdown = function() return true end
    M.__resetPrinted()
    -- red under: drop the lockdown check from Start
    assertFalse(NS.Preview.Start())
    assertFalse(NS.Preview.IsActive())
    assertEqual(printed(M, REFUSED), 1)
    M.InCombatLockdown = function() return false end
    NS.lifecycle:Hold("test")
    M.__resetPrinted()
    -- red under: drop the stood-down return from Start
    assertFalse(NS.Preview.Start())
    assertFalse(NS.Preview.IsActive())
    assertEqual(#M.__printed(), 0, "a stood-down start spoke")
    NS.lifecycle:Release("test")
end)

test("preview: PLAYER_REGEN_DISABLED ends it with the one ended line and gives the live bar back", function()
    local NS, M = scene()
    NS.Preview.Start()
    settle(M)
    M.__resetPrinted()
    M.__fire("PLAYER_REGEN_DISABLED")
    settle(M)
    -- red under: drop the combat receiver
    assertFalse(NS.Preview.IsActive())
    assertEqual(NS.State.testMode, false)
    assertEqual(printed(M, ENDED), 1)
    assertFalse(barShown(NS), "the bar test mode opened went away")
    assertFalse(stripShown(NS))
    -- Leaving combat does not bring it back.
    M.__fire("PLAYER_REGEN_ENABLED")
    settle(M)
    assertFalse(NS.Preview.IsActive())
end)

test("preview: a bar the player had on stays on, on the live outfits, when test mode ends", function()
    local NS, M = scene({ shown = true })
    local real = NS.Outfits.Create("Real", naked())
    settle(M)
    NS.Preview.Start()
    settle(M)
    assertEqual(NS.Preview.Diagnose().openedBar, false)
    NS.Preview.Stop()
    settle(M)
    assertTrue(barShown(NS))
    assertFalse(stripShown(NS))
    assertEqual(NS.Bar.Buttons()[1].outfit.id, real)
end)

test("preview: the stand-down ends it silently and the stand-up does not bring it back", function()
    local NS, M = scene()
    NS.Preview.Start()
    settle(M)
    M.__resetPrinted()
    NS.lifecycle:Hold("test")
    -- red under: an empty Preview.Suspend
    assertFalse(NS.Preview.IsActive())
    assertEqual(NS.State.testMode, false)
    assertEqual(printed(M, ENDED), 0, "the stand-down said the combat line")
    NS.lifecycle:Release("test")
    settle(M)
    assertFalse(NS.Preview.IsActive())
    assertFalse(barShown(NS))
end)

test("preview: Reset all and the General row's switch both end it", function()
    local NS, M = scene()
    NS.Preview.Start()
    settle(M)
    assertTrue(NS.FindSchemaRow("state.testMode").get() == true, "the row reads test mode")
    NS.Helpers.RestoreAllDefaults()
    settle(M)
    -- red under: a Stop that leaves `active` set
    assertFalse(NS.Preview.IsActive(), "Reset all left test mode on")
    assertFalse(barShown(NS))
    NS.FindSchemaRow("state.testMode").set(true)
    settle(M)
    assertTrue(NS.Preview.IsActive(), "the row's switch turns it on")
    NS.FindSchemaRow("state.testMode").set(false)
    settle(M)
    assertFalse(NS.Preview.IsActive(), "the row's switch turns it off")
end)

test("preview: re-locking the bar does not end it, and Toggle flips it", function()
    local NS, M = scene()
    NS.Preview.Toggle()
    settle(M)
    assertTrue(NS.Preview.IsActive())
    NS.SetByPath("locked", false)
    settle(M)
    NS.SetByPath("locked", true)
    settle(M)
    -- red under: a SETTINGS_CHANGED "locked" receiver in Preview that stops it
    assertTrue(NS.Preview.IsActive(), "re-locking ended test mode")
    assertTrue(stripShown(NS))
    NS.Preview.Toggle()
    settle(M)
    assertFalse(NS.Preview.IsActive())
end)

test("preview: Start and Stop each announce PREVIEW_CHANGED once, and a repeat is a no-op", function()
    local NS, M = scene()
    local seen = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.PREVIEW_CHANGED, function(_, on) seen[#seen + 1] = tostring(on) end)
    NS.Preview.Start()
    NS.Preview.Start()
    NS.Preview.Stop()
    -- red under: a Stop that answers true while already off
    assertFalse(NS.Preview.Stop())
    settle(M)
    assertEqual(table.concat(seen, ","), "true,false")
end)

test("preview: Diagnose reports the mode, the bar it opened and the sample count", function()
    local NS, M = scene()
    local d = NS.Preview.Diagnose()
    assertEqual(d.active, false)
    assertEqual(d.outfits, 0)
    NS.Preview.Start()
    settle(M)
    d = NS.Preview.Diagnose()
    assertEqual(d.active, true)
    assertEqual(d.openedBar, true)
    assertEqual(d.outfits, 5)
    assertEqual(NS.Preview.Source.Rows(), NS.PreviewOutfits.Rows())
end)

test("preview: every start and stop, from any source, repaints an open settings panel", function()
    -- options-ui-§15: the General checkbox follows every start and stop, not only its own click.
    local NS, M = scene()
    local paints = 0
    NS.Helpers.RefreshScalars = function() paints = paints + 1 end
    NS.Preview.Toggle()                               -- the launcher's entry and `/or test`
    -- red under: a Start that does not call NS.Helpers.RefreshScalars
    assertEqual(paints, 1, "a start did not repaint the panel")
    NS.Preview.Stop("switch")                          -- the strip's right-click
    -- red under: a Stop that does not call NS.Helpers.RefreshScalars
    assertEqual(paints, 2, "a stop did not repaint the panel")
    NS.Preview.Start()
    NS.SendBus(NS.MSG.PLAYER_STATE_CHANGED, "combat", true)
    settle(M)
    assertFalse(NS.Preview.IsActive())
    assertEqual(paints, 4, "the combat stop did not repaint the panel")
    NS.Preview.Start()
    NS.lifecycle:Hold("test")
    -- red under: a Suspend that does not call NS.Helpers.RefreshScalars
    assertEqual(paints, 6, "the stand-down did not repaint the panel")
    NS.lifecycle:Release("test")
    settle(M)
    NS.Preview.Stop()
    -- red under: a Stop that repaints while already off
    assertEqual(paints, 6, "a no-op stop repainted the panel")
end)

-- ── the window (smoke round 2 design G7, D9, D10) ─────────────────────────────────────────────
--
-- While test mode is on the window lists the sample outfits under its own test strip, docked beside
-- an open sheet or, with the sheet closed, alone where a stock sheet would put it: the same single
-- TOPLEFT -> UIParent BOTTOMLEFT point the dock always uses, issued only from Dock.Refresh. No item
-- section is listed, so no secure child arms, and every outfit-row handler refuses a sample quietly.
-- X or Escape hides it for the rest of that test session; the mode itself still ends only on its own
-- switch, combat or Reset all. The bar's strip under its header band is test_bar's.

local dockScene = dofile(T.root .. "/tests/dock_scene.lua")(T)

local SAMPLE_TIP = "Sample outfit (test mode). Nothing is equipped."

local SCREEN_TOP = 1080

--- The dock scene with UIParent laid out, so the alone corner has a screen top to hang from.
local function testScene(opts)
    local NS, M, fakes = dockScene(opts)
    M.__sheets.place(M.UIParent, 1920, SCREEN_TOP)
    return NS, M, fakes
end

local function outfitRows(NS)
    local out = {}
    for _, row in ipairs(NS.WindowRows.rows) do
        if row.entry and row.entry.kind == "outfit" then out[#out + 1] = row end
    end
    return out
end

local function realOutfit(NS)
    local items = { HeadSlot = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot")) }
    return NS.Outfits.Create("Real", items)
end

-- ── the list ──────────────────────────────────────────────────────────────────────────────────

test("preview window: the list is the five samples under their headers, no item section, nothing armed", function()
    local NS, M = testScene()
    local real = realOutfit(NS)
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    NS.Preview.Start()
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 1)
    local shape, outfits = {}, 0
    for _, e in ipairs(NS.Window.entries) do
        shape[#shape + 1] = e.kind .. ":" .. tostring(e.id)
        if e.kind == "outfit" then
            outfits = outfits + 1
            assertTrue(e.placeholder == true, "a listed outfit that is not a sample: " .. tostring(e.id))
        end
        -- red under: a preview branch that still appends NS.Inventory.ItemSections()
        assertTrue(e.kind ~= "item", "an item row in test mode")
        assertTrue(e.id ~= real, "the real outfit is listed in test mode")
    end
    assertEqual(table.concat(shape, ","),
        "category:Complete,outfit:preview:1,outfit:preview:2,outfit:preview:3,category:Accessory,outfit:preview:4,outfit:preview:5")
    assertEqual(outfits, 5)
    for _, row in ipairs(NS.WindowRows.rows) do assertFalse(row.secure:IsShown(), "a secure child armed") end
    local rows = outfitRows(NS)
    assertEqual(rows[1].name:GetText(), "Test Outfit 1")
    -- Each sample shows its row feature: 1 worn, 2 triggered, 4 in the Equipment Manager, 5 missing.
    assertTrue(rows[1].worn:GetChecked(), "sample 1 is drawn worn")
    assertFalse(rows[2].worn:GetChecked())
    assertTrue(rows[2].trig:IsShown(), "sample 2 shows the trigger mark")
    assertFalse(rows[1].trig:IsShown())
    assertEqual(rows[4].em:GetAlpha(), 1)
    assertTrue(rows[1].em:GetAlpha() < 1, "sample 1 is not stored in the Equipment Manager")
    assertEqual(rows[5].outfitArt:GetTexture(), NS.Constants.DEFAULT_OUTFIT_ICON)
    NS.Preview.Stop()
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 1)
    local back = false
    for _, e in ipairs(NS.Window.entries) do if e.id == real then back = true end end
    assertTrue(back, "the real outfits came back when test mode ended")
end)

test("preview window: every row handler refuses a sample quietly and nothing is written", function()
    local NS, M, fakes = testScene()
    M.__sheets.place(M.CharacterFrame, 300, 500)
    M.__world:openCharacter()
    NS.Dock.Open()
    NS.Preview.Start()
    M.OutfitterRebornDockDriver:__fire("OnUpdate", 1)
    local before, calls = snapshot(NS), #M.__equipCalls
    M.__resetPrinted()
    local rows = outfitRows(NS)
    assertEqual(#rows, 5)
    for _, row in ipairs(rows) do
        local was = row.worn:GetChecked()
        row:__fire("PreClick", "LeftButton")
        row:__fire("PostClick", "LeftButton")
        row:__fire("PostClick", "RightButton")
        row.worn:SetChecked(not was)
        row.worn:__fire("OnClick")
        -- red under: an onWornClick that returns without putting the box back
        assertEqual(row.worn:GetChecked(), was, "the worn box kept the click")
        row.em:__fire("OnClick", "LeftButton")
        row.menu:__fire("OnClick", "LeftButton")
        row:__fire("OnEnter")
        assertEqual(M.GameTooltip.TextLeft2:GetText(), SAMPLE_TIP)
        row:__fire("OnLeave")
    end
    M.__fireTimers()
    -- red under: a row click or worn box that reaches NS.Stack.Wear with the sample's id
    assertEqual(#M.__equipCalls, calls, "a sample reached the equip path")
    assertEqual(#NS.db.char.stack, 0, "nothing worn")
    assertEqual(fakes.OutfitMenu.__count("Open"), 0, "a sample opened the outfit menu")
    assertNil(NS.Stack.Selected(), "a sample was selected")
    assertEqual(#M.__printed(), 0, "a refusal spoke")
    assertEqual(snapshot(NS), before)
end)
