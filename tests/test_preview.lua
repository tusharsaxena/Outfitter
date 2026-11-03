-- tests/test_preview.lua — P4.22 (design §8, H17): test mode. modules/Preview.lua turns the outfit bar
-- over to defaults/PreviewOutfits.lua's five sample outfits under the amber strip; the window keeps
-- real data; nothing is equipped or saved; and the mode ends on its own switch, on combat (with one
-- line), on Reset all and, silently, on the stand-down, but not on re-locking the bar.
--
-- Every module it touches has landed (Bar, PlayerState, Outfits, the window's list model) and runs for
-- real; only NS.OutfitMenu (P4.21) is absent, and a placeholder's right-click never reaches it.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SAMPLES = {
    { "Test Outfit 1", 132276 }, { "Test Outfit 2", 1376041 }, { "Test Outfit 3", 136245 },
    { "Test Outfit 4", 132261 }, { "Test Outfit 5", 134062 },
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
    assertEqual(table.concat(icons, ","), "132276,1376041,136245,132261,134062")
    assertTrue(stripShown(NS), "the strip is up")
    assertEqual(NS.Bar.Frame().strip.text:GetText(), STRIP)
end)

test("preview: the window keeps real data while the bar shows the samples", function()
    local NS, M = scene()
    local real = NS.Outfits.Create("Real", naked())
    NS.Preview.Start()
    settle(M)
    local found, sample = false, false
    for _, e in ipairs(NS.WindowListModel.Build({}, {})) do
        local id = e.id or (e.outfit and e.outfit.id)
        if id == real then found = true end
        if type(id) == "string" and id:find("^preview:") then sample = true end
    end
    assertTrue(found, "the real outfit is in the window's list")
    assertFalse(sample, "a sample outfit reached the window")
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
