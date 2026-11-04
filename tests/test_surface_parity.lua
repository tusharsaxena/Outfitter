-- tests/test_surface_parity.lua — every degradation stub carries the surface of what it stands in for (testing-§8).
-- Each case loads the addon twice -- whole, and with the LibKa0s file list EMPTY -- and compares the
-- stub against the live surface, then drives both arms through the same calls.
--
-- THE P3 ROWS. C9 landed the Pool, Item and Widgets seams and SecureQueue, which is host code with
-- no stub and is asserted to behave the same on both arms. C14 adds the degraded load's init /
-- enable / version case and a row for every seam that landed before it: Options, Bus, Schema, Slash,
-- Lifecycle, Launcher, DebugLog, Perf, Core, Media, Env, Compat and Secrets (the Skin facade's row is
-- tests/test_skinsetup.lua's). Each later seam brought its own row, and P4.27 closed the set (design
-- §9.3): every LibKa0s major the host leases has its row, and the degraded load runs the whole login
-- walk and the latch over the real modules. A trimmed name in an `ignore` list is one this addon
-- never calls.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local live, degraded
local function pair()
    live = live or T.load()
    degraded = degraded or T.load{ libFiles = {} }
    return live, degraded
end

--- Each named member has the same type on the live and the library-absent load: the "asserted
--- present on both arms" half of testing-§8 for a seam whose stub is not a mirror of one table.
local function bothArms(label, get, members)
    local l, d = pair()
    for name, want in pairs(members) do
        assertEqual(type(get(l.NS)[name]), want, "live " .. label .. "." .. name)
        assertEqual(type(get(d.NS)[name]), want, "stub " .. label .. "." .. name)
    end
end

--- A frame-shaped object a pool can hand out: it remembers whether it is shown.
local function widget(n)
    local o = { n = n, shown = false }
    function o.Show(self) self.shown = true end
    function o.Hide(self) self.shown = false end
    return o
end

-- ── the degraded load, and the seams that landed before C14 ──────────────────────────────────

test("parity: the degraded load still initializes, enables and answers /or version", function()
    -- red under: any stub above that raises at load or in OnInitialize (the instance never gets a db)
    local _, d = pair()
    assertNil(d.mocks.LibStub("LibKa0s-Core-1.0", true), "the library is not absent")
    assertTrue(d.NS.db ~= nil, "InitDB ran")
    assertTrue(d.NS.addon ~= nil and d.NS.addon:IsEnabled() ~= false, "the addon did not enable")
    assertFalse(d.NS.IsStoodDown(), "the degraded load came up stood down")
    d.mocks.__resetPrinted()
    d.NS.Slash:OnSlash("version")
    local said = table.concat(d.mocks.__printed(), "\n")
    assertTrue(said:find("1.1.0", 1, true) ~= nil, "/or version answered: " .. said)
end)

--- Form two against an INSTANCE: the stub mirrors what `lib:New(descriptor)` returned, so the
--- source is swapped to that instance for the one call and put back (testing-§8).
local function againstInstance(stub, major, liveInstance, ignore)
    local previous = T.setSurfaceSource({ [major] = liveInstance })
    local ok, err = pcall(T.assertSurfaceParity, stub, major, ignore)
    T.setSurfaceSource(previous)
    if not ok then error(err, 0) end
end

test("parity: the Options stub carries every public member of the live Helpers surface", function()
    local l, d = pair()
    againstInstance(d.NS.Helpers, "LibKa0s-Options-1.0", l.NS.Helpers, {
        -- constants and composers no page of this addon reads (grep -rhoE "(Helpers|\bH)\.[A-Za-z_]+"
        -- core/ modules/ settings/), so a full load alone carries them
        "CLASS_COLOR_NOTE", "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_SORT", "VISIBILITY_VALUES",
        "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL", "PADDING_X", "CHROME_GAP", "TAB_H",
        "BANNER_H", "PageHeader", "SubTabStrip", "AceGUI",
    })
end)

test("parity: the Bus stub carries the library surface, and its record the instance's", function()
    local l, d = pair()
    assertTrue(d.NS.BusLib ~= l.mocks.LibStub("LibKa0s-Bus-1.0"), "the degraded load did not take the stub")
    T.assertSurfaceParity(d.NS.BusLib, "LibKa0s-Bus-1.0")
    T.assertSurfaceParity(l.NS.busRecord, d.NS.busRecord, "NS.busRecord")
end)

test("parity: the Schema stub carries the runtime surface this addon binds", function()
    -- members from: grep -rhoE "\bS[.:][A-Z][A-Za-z]+" settings/ (AddRows, AllRows, ApplyDefault,
    -- BulkBegin, BulkEnd, BulkRun, FindRow, Get, Set, SetMany, Validate); the rest are never called
    local l, d = pair()
    T.assertSurfaceParity(l.NS.SchemaRuntime, d.NS.SchemaRuntime, "NS.SchemaRuntime", {
        "Reindex", "Default", "BulkAdd", "InBulk", "CountOffDefault", "ResetCounted", "ConsumeResetCount",
    })
    T.assertSurfaceParity(l.NS.__schemaLib, d.NS.__schemaLib, "NS.__schemaLib",
        { "STRINGS", "SameValue", "MAJOR", "MINOR", "MODULES" })
end)

test("parity: the Slash stub carries the live dispatcher's surface", function()
    local l, d = pair()
    T.assertSurfaceParity(l.NS.Slash.__dispatcher, d.NS.Slash.__dispatcher, "NS.Slash.__dispatcher", {
        "BuildListLines", -- the schema CLI's listing; the stub's CliList names the missing library
        "HelpHeader",     -- the stub's PrintHelp prints its own plain header
        "Text",           -- lib.STRINGS; the stub carries no library string but the refusal format
    })
end)

test("parity: the Lifecycle stub carries the live latch's surface", function()
    local l, d = pair()
    assertTrue(d.NS.lifecycle == d.NS.Lifecycle, "the two names are not one object")
    T.assertSurfaceParity(l.NS.lifecycle, d.NS.lifecycle, "NS.lifecycle")
end)

test("parity: the Launcher stub carries the live launcher's surface", function()
    local l, d = pair()
    T.assertSurfaceParity(l.NS.Launcher, d.NS.Launcher, "NS.Launcher")
end)

test("parity: the DebugLog stub carries every member this addon calls", function()
    -- members from: grep -rhoE "DebugLog[.:][A-Za-z]+" core/ modules/ settings/, plus Hide,
    -- IsEnabled and SetEnabled, which the console row and the diagnostics contract reach
    bothArms("NS.DebugLog", function(NS) return NS.DebugLog end, {
        Add = "function", Debug = "function", Show = "function", Hide = "function",
        Toggle = "function", IsShown = "function", IsEnabled = "function", SetEnabled = "function",
        ConsoleCheckbox = "function", RunDiagnostics = "function", DebugVerb = "function",
        DebugOnce = "function", DebugChanged = "function", DebugAtEnable = "function",
    })
    bothArms("NS", function(NS) return NS end, {
        Debug = "function", DebugOnce = "function", DebugChanged = "function", DebugAtEnable = "function",
    })
end)

test("parity: the Perf stub carries every member this addon reads, on both arms", function()
    -- members from: grep -rhoE "Perf[.:][A-Za-z]+" core/ modules/ settings/
    bothArms("NS.Perf", function(NS) return NS.Perf end,
        { on = "boolean", Note = "function", OnCommand = "function" })
    local _, d = pair()
    local lines = d.NS.Perf.OnCommand("")
    assertEqual(type(lines), "table", "the stub's perf verb answers no lines")
    assertTrue(tostring(lines[1]):find(d.NS.LIBKA0S_MISSING, 1, true) ~= nil, "the stub does not say why")
end)

test("parity: the Core seam carries every member this addon reads, on both arms", function()
    -- members from: grep -rhoE "NS\.(Print|SafeToString|IsConcatSafe|SafeRegister[A-Za-z]*|ApplySkin|SKIN|MakeCloseButton|MakeResizable|RaiseStaticPopups)\b" core/ modules/ settings/
    bothArms("NS", function(NS) return NS end, {
        Print = "function", SafeToString = "function", IsConcatSafe = "function",
        SafeRegisterEvent = "function", SafeRegisterUnitEvent = "function",
        SafeRegisterEvents = "function", ApplySkin = "function", SKIN = "table",
        MakeCloseButton = "function", MakeResizable = "function", RaiseStaticPopups = "function",
    })
    bothArms("NS.Util", function(NS) return NS.Util end, { print = "function" })
    local l, d = pair()
    assertTrue(l.NS.Print == l.NS.Util.print, "live: NS.Print is not NS.Util.print (architecture-§2)")
    assertTrue(d.NS.Print == d.NS.Util.print, "stub: NS.Print is not NS.Util.print (architecture-§2)")
end)

test("parity: the Media seam answers on both arms, nil being a real answer", function()
    -- members from: grep -rhoE "NS\.(Icon|MediaFont)\b" core/ modules/ settings/
    bothArms("NS", function(NS) return NS end, { Icon = "function", MediaFont = "function" })
    local _, d = pair()
    assertNil(d.NS.Icon("close"), "the stub invented an icon path")
    assertNil(d.NS.MediaFont("any"), "the stub invented a font path")
end)

test("parity: the IconBrowser seam's glyph helpers answer on both arms, the stub drawing no glyph", function()
    -- members from: grep -rhoE "NS\.Glyph\.[A-Za-z]+" modules/ settings/ core/
    bothArms("NS.Glyph", function(NS) return NS.Glyph end,
        { IsGlyph = "function", ValidColor = "function", Tint = "function" })
    local l, d = pair()
    local lib = l.mocks.LibStub("LibKa0s-IconBrowser-1.0")
    local path = l.NS.Icon("ph:sword")
    assertEqual(l.NS.Glyph.IsGlyph(path), lib.IsGlyph(path))
    assertEqual(l.NS.Glyph.IsGlyph(path), "ph:sword")
    assertNil(l.NS.Glyph.IsGlyph(135349), "a fileID is not a glyph")
    -- red under: a stub that reads any string as a glyph (a stored glyph would draw blank).
    assertNil(d.NS.Glyph.IsGlyph(path), "the stub read a glyph with no library")
    for arm, NS in pairs({ live = l.NS, degraded = d.NS }) do
        assertTrue(NS.Glyph.ValidColor(nil), arm .. ": none is a color")
        assertFalse(NS.Glyph.ValidColor(false), arm .. ": false is not stored")
        assertFalse(NS.Glyph.ValidColor("red"), arm)
        local r, g, b = NS.Glyph.Tint(nil)
        assertTrue(r == 1 and g == 1 and b == 1, arm .. ": no color is white")
    end
    assertTrue(l.NS.Glyph.ValidColor("ff8000"))
    local r, g, b = d.NS.Glyph.Tint("ff0000")
    assertTrue(r == 1 and g == 1 and b == 1, "the stub tints nothing")
end)

test("parity: the Env seam answers the TOC's version on both arms", function()
    -- members from: grep -rhoE "NS\.(Meta|Version)\b" core/ modules/ settings/
    bothArms("NS", function(NS) return NS end, { Meta = "function", Version = "function" })
    local l, d = pair()
    assertEqual(d.NS.Version(), l.NS.Version(), "the stub reads a different version")
    assertEqual(d.NS.Meta("Version"), l.NS.Meta("Version"))
end)

test("parity: the Compat and Secrets seams carry the same surface on both arms", function()
    -- Host tables over LibKa0s-Compat-1.0 (core/Compat.lua, core/Secrets.lua): every member the
    -- full load publishes is published, as the same kind, when the library is absent.
    -- members from: grep -rhoE "NS\.(IsSecret|Unsecret|SafeNumber)\b" core/ modules/ settings/
    local l, d = pair()
    T.assertSurfaceParity(l.NS.Compat, d.NS.Compat, "NS.Compat")
    T.assertSurfaceParity(l.NS.Secrets, d.NS.Secrets, "NS.Secrets")
    bothArms("NS", function(NS) return NS end,
        { IsSecret = "function", Unsecret = "function", SafeNumber = "function" })
end)

-- ── Pool ───────────────────────────────────────────────────────────────────────────────────────

test("parity: the Pool stub carries every public member of the library", function()
    -- Both shapes: the array pool (list rows, bar buttons, the icon grid) and the keyed pool (the
    -- trigger dialog's editors, design §7.6), whose only release is ReleaseAllKeyed.
    local l, d = pair()
    assertTrue(l.NS.Pool == l.mocks.LibStub("LibKa0s-Pool-1.0"), "the live NS.Pool is not the library")
    assertTrue(d.NS.Pool ~= l.NS.Pool, "the degraded load did not take the stub")
    T.assertSurfaceParity(d.NS.Pool, "LibKa0s-Pool-1.0")
end)

test("parity: both Pool arms recycle, park backward and key alike", function()
    -- red under: a stub ReleaseAll that only hides (Counts answers 0, 0 and the next Acquire builds),
    -- or one that parks forward (the second render hands position 1 the object position 3 had).
    for arm, inst in pairs({ live = (pair()), degraded = select(2, pair()) }) do
        local P, built = inst.NS.Pool, 0
        local function factory() built = built + 1; return widget(built) end
        local pool = P.New()
        local first = { P.Acquire(pool, factory), P.Acquire(pool, factory), P.Acquire(pool, factory) }
        assertTrue(first[1].shown, arm .. ": an acquired object is shown")
        local seen = {}
        P.ReleaseAll(pool, function(o) seen[#seen + 1] = o.shown end)
        assertEqual(#seen, 3, arm .. ": before ran per object")
        assertTrue(seen[1], arm .. ": before runs while the object is still shown")
        assertFalse(first[1].shown, arm .. ": a released object is hidden")
        local free, active = P.Counts(pool)
        assertEqual(free, 3, arm .. ": free after release"); assertEqual(active, 0, arm)
        for i = 1, 3 do
            assertTrue(P.Acquire(pool, factory) == first[i], arm .. ": position " .. i .. " got another object")
        end
        assertEqual(built, 3, arm .. ": the second render built")

        local keyed = P.NewKeyed()
        local a = P.AcquireKeyed(keyed, "text", factory)
        assertTrue(P.AcquireKeyed(keyed, "text", factory) == a, arm .. ": a live key built a second object")
        P.AcquireKeyed(keyed, "spell", factory)
        free, active = P.CountsKeyed(keyed)
        assertEqual(free, 0, arm); assertEqual(active, 2, arm .. ": keyed active")
        local keys = {}
        P.ReleaseAllKeyed(keyed, function(_, key) keys[key] = true end)
        assertTrue(keys.text and keys.spell, arm .. ": before is handed each key")
        free, active = P.CountsKeyed(keyed)
        assertEqual(free, 2, arm .. ": keyed free"); assertEqual(active, 0, arm)
        assertFalse(a.shown, arm .. ": a released keyed object is hidden")
    end
end)

-- ── Item ───────────────────────────────────────────────────────────────────────────────────────

-- Links the two walks must read alike: a full link with bonuses and modifiers, a bare itemString, a
-- signed field, an empty bonus count, a declared count longer than the link, a non-numeric field
-- inside the span, the 11.1.5 quality prefix, and strings that are no item at all.
local LINKS = {
    "|cffa335ee|Hitem:212400::::::::80:577::6:4:10356:10299:1540:10255:1:28:2734:::::|h[Item]|h|r",
    "item:19019:0:0:0:0:0:0:0:60",
    "item:6948::::::-12::::::",
    "|cnIQ4:|Hitem:224072::::::::80:577::3:2:10390:6652::::::|h[Item]|h|r",
    "item:1:::::::::::::5:7:8",
    "item:2:::::::::::::3:4:x:6",
    "item:abc",
    "|Hspell:1234|h[Spell]|h",
    "",
}

test("parity: the Item lease carries the same two members on both arms", function()
    bothArms("NS.Item", function(NS) return NS.Item end,
        { ItemIDFromLink = "function", BonusIDsFromLink = "function" })
end)

test("parity: the Item fallback reads every link as the library does", function()
    -- red under: any drift of the fallback walks in core/ItemSetup.lua from libs/LibKa0s/Item.lua
    -- (reading field 13 as an id, dropping empty fields when splitting, a non-numeric id read as 0).
    local l, d = pair()
    local lib = l.mocks.LibStub("LibKa0s-Item-1.0")
    for _, link in ipairs(LINKS) do
        assertEqual(l.NS.Item.ItemIDFromLink(link), lib.ItemIDFromLink(link), "live id of " .. link)
        assertEqual(d.NS.Item.ItemIDFromLink(link), lib.ItemIDFromLink(link), "stub id of " .. link)
        local want = lib.BonusIDsFromLink(link)
        local liveGot, stubGot = l.NS.Item.BonusIDsFromLink(link), d.NS.Item.BonusIDsFromLink(link)
        if want == nil then
            assertNil(liveGot, "live bonuses of " .. link); assertNil(stubGot, "stub bonuses of " .. link)
        else
            assertEqual(table.concat(liveGot, ","), table.concat(want, ","), "live bonuses of " .. link)
            assertEqual(table.concat(stubGot, ","), table.concat(want, ","), "stub bonuses of " .. link)
        end
    end
    assertEqual(table.concat(d.NS.Item.BonusIDsFromLink(LINKS[1]), ","), "10356,10299,1540,10255")
    assertEqual(d.NS.Item.ItemIDFromLink(LINKS[1]), 212400)
end)

test("parity: on both arms the Item lease answers nil for a non-string and a secret link", function()
    -- red under: dropping the NS.Secrets.PlainString read from core/ItemSetup.lua (a secret link
    -- reaches :match).
    local l, d = pair()
    local restore = T.installSecretValue()
    local ok, err = pcall(function()
        for arm, NS in pairs({ live = l.NS, degraded = d.NS }) do
            local secret = T.secret("item:19019:0:0:0:0:0:0:0:60")
            assertNil(NS.Item.ItemIDFromLink(secret), arm .. ": a secret link was read")
            assertNil(NS.Item.BonusIDsFromLink(secret), arm .. ": a secret link was walked")
            assertNil(NS.Item.ItemIDFromLink(nil), arm)
            assertNil(NS.Item.BonusIDsFromLink(19019), arm)
        end
    end)
    restore()
    if not ok then error(err, 0) end
end)

-- ── Widgets ────────────────────────────────────────────────────────────────────────────────────

test("parity: the Widgets seam answers on both arms, nil being a real answer", function()
    -- The seam exports no copy window: no shipped feature opens one (the diagnostics report is
    -- copied from the debug console's own Copy button). red under: restoring NS.ShowCopy in
    -- core/WidgetsSetup.lua.
    bothArms("NS", function(NS) return NS end, {
        MakeDropdown = "function", OpenMenu = "function", CloseMenu = "function",
        MakeTestStrip = "function", TEST_STRIP_HEIGHT = "number",
    })
    local l, d = pair()
    assertNil(l.NS.ShowCopy, "the live load exports a copy window no feature opens")
    assertNil(d.NS.ShowCopy, "the stub exports a copy window no feature opens")
    T.assertLibraryConstant(d.NS.TEST_STRIP_HEIGHT, "LibKa0s-Widgets-1.0", "TEST_STRIP.HEIGHT",
        "the stub's strip height")
    assertTrue(l.NS.MakeDropdown(l.mocks.UIParent, 100) ~= nil, "the live load drew no dropdown")
    assertTrue(l.NS.MakeTestStrip(l.mocks.UIParent, "Test mode") ~= nil, "the live load drew no strip")
    assertNil(d.NS.MakeDropdown(d.mocks.UIParent, 100), "the stub drew a dead dropdown")
    assertNil(d.NS.MakeTestStrip(d.mocks.UIParent, "Test mode"), "the stub drew a strip")
    d.NS.CloseMenu()
    l.NS.CloseMenu()
end)

test("parity: OpenMenu draws the same fill on both arms", function()
    -- The fill is written once, against MenuUtil's description. red under: a recorder that drops a
    -- disabled state, or a submenu row that runs its own (absent) click instead of opening its level.
    local l, d = pair()
    local clicks = {}
    local function fill(root)
        root:CreateTitle("Outfit")
        root:CreateButton("Wear", function() clicks[#clicks + 1] = "wear" end)
        root:CreateButton("Bank", function() clicks[#clicks + 1] = "bank" end):SetEnabled(false)
        local sub = root:CreateButton("Key binding")
        sub:CreateButton("Outfit 1", function() clicks[#clicks + 1] = "bind1" end)
    end

    local W = l.mocks.LibStub("LibKa0s-Widgets-1.0")
    local real, menus = W.ContextMenu, {}
    W.ContextMenu = function(_, rows, opts) menus[#menus + 1] = { rows = rows, opts = opts } end
    local ok, err = pcall(function()
        assertTrue(l.NS.OpenMenu(l.mocks.UIParent, fill), "the live arm did not open")
        local rows = menus[1].rows
        assertEqual(#rows, 4)
        assertTrue(rows[1].title, "the title row")
        assertNil(rows[2].disabled); assertTrue(rows[3].disabled, "the disabled row")
        assertTrue(menus[1].opts.cursor, "the menu opens at the cursor")
        rows[2].onClick()
        rows[4].onClick()   -- the submenu row opens its own level in the menu's place
        assertEqual(#menus, 2, "the submenu level did not open")
        assertEqual(menus[2].rows[1].label, "Outfit 1")
        menus[2].rows[1].onClick()
    end)
    W.ContextMenu = real
    if not ok then error(err, 0) end
    assertEqual(table.concat(clicks, ","), "wear,bind1")

    -- The degraded arm hands the same fill to the client's menu, and opens nothing without one.
    assertFalse(d.NS.OpenMenu(d.mocks.UIParent, fill), "no MenuUtil, yet it claimed a menu")
    local described
    d.mocks.MenuUtil = { CreateContextMenu = function(owner, gen)
        local root = { n = 0 }
        function root.CreateTitle(self) self.n = self.n + 1 end
        function root.CreateButton(self)
            self.n = self.n + 1
            return { SetEnabled = function() end, CreateButton = function() end }
        end
        gen(owner, root)
        described = root.n
    end }
    local ok2, err2 = pcall(function()
        assertTrue(d.NS.OpenMenu(d.mocks.UIParent, fill), "the degraded arm did not open")
    end)
    d.mocks.MenuUtil = nil
    if not ok2 then error(err2, 0) end
    assertEqual(described, 4, "the client's menu was not handed the fill")
end)

-- ── SecureQueue (host code: no stub, and the same on both arms) ────────────────────────────────

--- The PLAYER_REGEN_ENABLED registrations an instance holds.
local function regenRegistrations(mocks)
    local n = 0
    for _, reg in ipairs(mocks.__registrations()) do
        if reg.event == "PLAYER_REGEN_ENABLED" then n = n + 1 end
    end
    return n
end

--- Run `fn(NS, mocks, setLocked, arm, before)` on a FRESH instance of each arm, with lockdown under
--- the case's control: the queue is file state, so a shared instance would carry one case's
--- registration into the next case's `before`.
local function eachArm(fn)
    for _, arm in ipairs({ "live", "degraded" }) do
        local inst = arm == "live" and T.load() or T.load{ libFiles = {} }
        local locked = false
        local before = regenRegistrations(inst.mocks)
        inst.mocks.InCombatLockdown = function() return locked end
        local ok, err = pcall(fn, inst.NS, inst.mocks, function(v) locked = v end, arm, before)
        if not ok then error(arm .. ": " .. tostring(err), 0) end
    end
end

test("secure queue: out of lockdown a write runs now, and nothing is registered", function()
    eachArm(function(NS, M, _, arm, before)
        local ran = 0
        assertTrue(NS.SecureQueue.Run("dock.layers", function() ran = ran + 1 end), arm)
        assertEqual(ran, 1, arm)
        assertEqual(regenRegistrations(M), before, arm .. ": an idle queue holds a registration")
    end)
end)

test("secure queue: in lockdown a write waits, the latest per key wins, and REGEN_ENABLED replays in order", function()
    -- red under: running the write in lockdown, keeping the first fn of a key, a pairs-ordered flush,
    -- or a registration kept after the queue empties.
    eachArm(function(NS, M, setLocked, arm, before)
        local Q, got = NS.SecureQueue, {}
        setLocked(true)
        assertFalse(Q.Run("dock.layers", function() got[#got + 1] = "layers-old" end), arm)
        assertFalse(Q.Run("list.rows", function() got[#got + 1] = "rows" end), arm)
        assertFalse(Q.Run("dock.layers", function() got[#got + 1] = "layers" end), arm)
        assertEqual(#got, 0, arm .. ": a write ran in lockdown")
        assertEqual(regenRegistrations(M), before + 1, arm .. ": not registered while waiting")
        assertEqual(Q.Flush(), 0, arm .. ": a flush still in lockdown ran something")
        setLocked(false)
        M.__fire("PLAYER_REGEN_ENABLED")
        assertEqual(table.concat(got, ","), "layers,rows", arm)
        assertEqual(regenRegistrations(M), before, arm .. ": the registration outlived the queue")
        assertEqual(Q.Flush(), 0, arm .. ": a second flush replayed")
    end)
end)

test("secure queue: a write out of lockdown drops the stale one under its key", function()
    eachArm(function(NS, M, setLocked, arm, before)
        local Q, got = NS.SecureQueue, {}
        setLocked(true)
        Q.Run("bar.attrs", function() got[#got + 1] = "stale" end)
        setLocked(false)
        Q.Run("bar.attrs", function() got[#got + 1] = "now" end)
        assertEqual(regenRegistrations(M), before, arm .. ": the dropped key kept the registration")
        M.__fire("PLAYER_REGEN_ENABLED")
        assertEqual(table.concat(got, ","), "now", arm)
    end)
end)

test("secure queue: one raising write reaches the error handler and the rest still run", function()
    eachArm(function(NS, M, setLocked, arm)
        local Q, got, errors = NS.SecureQueue, {}, {}
        M.geterrorhandler = function() return function(e) errors[#errors + 1] = e end end
        setLocked(true)
        Q.Run("a", function() error("boom", 0) end)
        Q.Run("b", function() got[#got + 1] = "b" end)
        setLocked(false)
        local ok, err = pcall(Q.Flush)
        M.geterrorhandler = nil
        if not ok then error(err, 0) end
        assertEqual(table.concat(got, ","), "b", arm .. ": the raise stranded the next write")
        assertEqual(errors[1], "boom", arm .. ": the raise was swallowed")
    end)
end)

test("secure queue: Clear drops every waiting write and the registration", function()
    eachArm(function(NS, M, setLocked, arm, before)
        local Q, ran = NS.SecureQueue, 0
        setLocked(true)
        Q.Run("a", function() ran = ran + 1 end)
        Q.Clear()
        assertEqual(regenRegistrations(M), before, arm .. ": Clear kept the registration")
        setLocked(false)
        M.__fire("PLAYER_REGEN_ENABLED")
        assertEqual(Q.Flush(), 0, arm)
        assertEqual(ran, 0, arm .. ": a cleared write ran")
    end)
end)

-- ── the closed set (P4.27) ────────────────────────────────────────────────────────────────────

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "rb"))
    local text = f:read("*a")
    f:close()
    return text
end

--- The LibKa0s majors the authored files lease, by short name ("Bus" for LibKa0s-Bus-1.0).
local function leasedMajors()
    local out, seen = {}, {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") then
            for name in readFile(rel):gmatch('LibStub%(?%s*"LibKa0s%-(%a+)%-1%.0"') do
                if not seen[name] then
                    seen[name] = true
                    out[#out + 1] = name
                end
            end
        end
    end
    table.sort(out)
    return out
end

-- The suite that carries a major's row when it is not this one.
local ROW_HOME = { Skin = "tests/test_skinsetup.lua" }

--- The majors in `majors` whose home suite has no parity case naming them.
local function uncovered(majors, sources)
    local missing = {}
    for _, name in ipairs(majors) do
        local text = sources[ROW_HOME[name] or "tests/test_surface_parity.lua"] or ""
        local found = false
        for title in text:gmatch('\ntest%("([^"]+)"') do
            local lower = title:lower()
            if (lower:find("parity", 1, true) or lower:find("degraded", 1, true))
                and lower:find("%f[%a]" .. name:lower() .. "%f[%A]") then
                found = true
            end
        end
        if not found then missing[#missing + 1] = name end
    end
    return missing
end

test("parity: every LibKa0s major the host leases has its parity row", function()
    -- red under: retitle the Lifecycle case above without the word Lifecycle (its seam has no row).
    local majors = leasedMajors()
    assertTrue(#majors >= 16, "the lease scan found " .. #majors .. " majors; it is broken")
    local sources = {
        ["tests/test_surface_parity.lua"] = readFile("tests/test_surface_parity.lua"),
        ["tests/test_skinsetup.lua"] = readFile("tests/test_skinsetup.lua"),
    }
    assertEqual(table.concat(uncovered(majors, sources), ", "), "")
    -- The scan itself: a major with no row is reported.
    assertEqual(table.concat(uncovered({ "Nope" }, sources), ","), "Nope")
end)

--- Every registration key of an instance, sorted.
local function regKeys(inst)
    local out = {}
    for _, r in ipairs(inst.mocks.__registrations()) do
        out[#out + 1] = ("%s|%s|%s|%s"):format(tostring(r.target or r.owner), tostring(r.kind),
            tostring(r.event), tostring(r.unit))
    end
    table.sort(out)
    return out
end

test("parity: the degraded load resumes every module at login, and stands them down and up", function()
    -- red under: a module Resume that reaches a LibKa0s major with no stub (the degraded login raises
    -- inside OnEnable and the walk stops short).
    local d = T.load({ libFiles = {}, mutate = function(M) M.__gear:load("geared") end })
    local NS, M = d.NS, d.mocks
    assertFalse(NS.IsStoodDown())
    -- The login resume binds nothing: the first LoadPass does (F-002).
    assertFalse(NS.TriggerBinder.IsActive(), "the binder bound before the degraded LoadPass")
    assertTrue(NS.Dock.Holder() ~= nil, "the dock did not install on the degraded login")
    M.__fire("PLAYER_ENTERING_WORLD")
    for _ = 1, 4 do if M.__fireTimers() == 0 then break end end
    assertTrue(NS.db.char.seeded == true, "the degraded LoadPass did not run")
    assertTrue(NS.TriggerBinder.IsActive(), "the binder did not bind at the degraded LoadPass")
    local up = table.concat(regKeys(d), ",")
    assertTrue(#up > 0)
    NS.RunVerb("disable")
    assertEqual(#regKeys(d), 0, "the degraded stand-down left a registration")
    assertEqual(#M.__timers(), 0, "the degraded stand-down left a timer")
    NS.RunVerb("enable")
    assertEqual(table.concat(regKeys(d), ","), up, "the degraded stand-up rebuilt another set")
end)
