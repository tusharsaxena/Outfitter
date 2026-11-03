-- tests/test_diagnostics.lua — P4.26 (design §12 row P4.26, §6.5 ZoneInfo, §5.10 Diagnostic, INV §4,
-- INV §16 quirk 4): what `/of zone` and `/of diagnostics` show.
--
-- `NS.States.ZoneInfo()` and `NS.Equip.Diagnostic()` are called directly here; the `/of zone` route
-- (Commands.Zone printing one after the other) is test_slash's, P4.24. The rest pins this addon's
-- sections of the diagnostics report (modules/Diagnostics.lua): the zone producer's view, the
-- equipment bracket's lines with the STUCK tripwire, the faulted and unavailable trigger bindings,
-- every rejected event name, and whether the old Outfitter is loaded. The modules are the real ones:
-- every module these sections read landed before group J.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local STUCK = "Equipment updates are STUCK (count 2) -- reload to clear"

-- A fresh instance with the zone producer listening and its first read done.
local function scene()
    local inst = T.load()
    local NS, M = inst.NS, inst.mocks
    M.__now = 100
    NS.PlayerState.Resume()
    NS.Equip.Resume()
    NS.States.ResumeZone()
    M.__fireTimers()
    return { NS = NS, M = M, W = M.__world }
end

local function enter(s, spec)
    s.W:setInstance(spec)
    s.M.__fire("ZONE_CHANGED_NEW_AREA")
    s.M.__fireTimers()
end

-- A stand-in for the library's writer: `add` formats %s-only over tostring'd arguments, as the real
-- one does; `joined`/`list` write `lead` and the parts comma-joined (`lead -` when empty).
local function recorder()
    local out = { lines = {} }
    function out.add(_, tag, fmt, ...)
        local n, args = select("#", ...), { ... }
        for i = 1, n do args[i] = tostring(args[i]) end
        out.lines[#out.lines + 1] = { tag, fmt:format(unpack(args, 1, n)) }
        return true
    end
    function out.joined(self, tag, lead, parts)
        if type(parts) ~= "table" or #parts == 0 then return self:add(tag, "%s -", lead) end
        local s = {}
        for i = 1, #parts do s[i] = tostring(parts[i]) end
        return self:add(tag, "%s %s", lead, table.concat(s, ", "))
    end
    out.list = out.joined
    function out.nonDefaults() return true end
    return out
end

-- The text lines one named section writes (nil when the report has no such section).
local function section(NS, name)
    for _, sec in ipairs(NS.Diagnostics.Sections()) do
        if sec[1] == name then
            local out = recorder()
            sec[2](out)
            local text = {}
            for i, l in ipairs(out.lines) do text[i] = l[2] end
            return text
        end
    end
    return nil
end

local function has(lines, want)
    for _, l in ipairs(lines or {}) do if l == want then return true end end
    return false
end

local function shown(lines) return table.concat(lines or {}, " | ") end

-- ── /of zone: the two producers, called directly ─────────────────────────────────────────────

test("diagnostics: ZoneInfo gives the instance line and the active zone outfits", function()
    local s = scene()
    enter(s, { name = "Ruins of Lordaeron", type = "arena", instanceID = 572 })
    local lines = s.NS.States.ZoneInfo()
    assertEqual(lines[1], "Instance: Ruins of Lordaeron (type arena, map ID 572)")
    assertEqual(lines[2], "Zone outfits active: PVP_BATTLEGROUND, PVP_ARENA, ARENA_LORDAERON")
    assertEqual(#lines, 2, shown(lines))
end)

test("diagnostics: ZoneInfo names a map the zone table misses", function()
    local s = scene()
    enter(s, { name = "New Arena", type = "arena", instanceID = 99999 })
    local lines = s.NS.States.ZoneInfo()
    assertEqual(lines[2], "This map has no entry in the zone table")
    assertEqual(lines[3], "Zone outfits active: PVP_BATTLEGROUND, PVP_ARENA")
end)

test("diagnostics: ZoneInfo says when no zone outfit applies", function()
    local s = scene()
    enter(s, nil)
    local lines = s.NS.States.ZoneInfo()
    assertEqual(lines[#lines], "No zone outfits apply here")
    assertFalse(has(lines, "This map has no entry in the zone table") and lines[2] == nil)
end)

test("diagnostics: Equip.Diagnostic carries the STUCK line only while depth outruns the batches", function()
    local s = scene()
    local E, st = s.NS.Equip, s.NS.Equip.__state
    local lines = E.Diagnostic()
    assertFalse(has(lines, STUCK), shown(lines))
    local inside
    E.Batch(function() inside = E.Diagnostic() end)
    -- red under: the tripwire testing `depth > 0` (pinned in test_equip_bracket too).
    assertFalse(has(inside, "Equipment updates are STUCK (count 1) -- reload to clear"), "a running batch")
    st.depth = 2                                     -- quirk 4: an End that never came
    lines = E.Diagnostic()
    assertEqual(lines[#lines], STUCK)
end)

-- ── /of diagnostics: this addon's sections ───────────────────────────────────────────────────

test("diagnostics: the report's sections, in order", function()
    local names = {}
    for i, sec in ipairs(T.NS.Diagnostics.Sections()) do
        names[i] = sec[1]
        assertEqual(type(sec[2]), "function", sec[1])
    end
    -- red under: Sections() without the zone, equip and bindings entries.
    assertEqual(table.concat(names, ","), "identity,settings,state,zone,equip,bindings,rejected")
end)

test("diagnostics: the zone section is ZoneInfo's lines", function()
    local s = scene()
    enter(s, { name = "New Arena", type = "arena", instanceID = 99999 })
    local want = s.NS.States.ZoneInfo()
    local got = section(s.NS, "zone")
    assertEqual(shown(got), shown(want))
    assertTrue(has(got, "This map has no entry in the zone table"), shown(got))
    enter(s, nil)
    local open = section(s.NS, "zone")
    assertEqual(open[#open], "No zone outfits apply here")
end)

test("diagnostics: the equip section is Equip.Diagnostic's lines, STUCK included", function()
    local s = scene()
    assertEqual(shown(section(s.NS, "equip")), shown(s.NS.Equip.Diagnostic()))
    assertFalse(has(section(s.NS, "equip"), STUCK))
    s.NS.Equip.__state.depth = 2
    -- red under: an equip section that stops at the first three lines (the tripwire never shows).
    assertTrue(has(section(s.NS, "equip"), STUCK), shown(section(s.NS, "equip")))
end)

test("diagnostics: the bindings section lists faulted bindings with their errors, sorted", function()
    local s = scene()
    local B = s.NS.TriggerBinder
    local lines = section(s.NS, "bindings")
    assertTrue(has(lines, "faulted bindings -"), shown(lines))
    assertTrue(has(lines, "unavailable triggers -"), shown(lines))
    B.faulted["o2:MOUNTED"] = "boom at line 3"
    B.faulted["o1:SWIMMING"] = "attempt to index nil"
    B.unavailable.GONE = true
    lines = section(s.NS, "bindings")
    -- red under: a bindings section that ignores B.faulted.
    assertTrue(has(lines, "faulted bindings: 2"), shown(lines))
    local a, b
    for i, l in ipairs(lines) do
        if l == "faulted o1:SWIMMING: attempt to index nil" then a = i end
        if l == "faulted o2:MOUNTED: boom at line 3" then b = i end
    end
    assertTrue(a ~= nil and b ~= nil and a < b, shown(lines))
    assertTrue(has(lines, "unavailable triggers GONE"), shown(lines))
end)

test("diagnostics: the rejected section names the core's and the binder's refused events", function()
    local s = scene()
    local lines = section(s.NS, "rejected")
    assertTrue(has(lines, "rejected events -"), shown(lines))
    assertTrue(has(lines, "binder rejected events -"), shown(lines))
    s.NS.rejectedEvents[#s.NS.rejectedEvents + 1] = "OLD_EVENT"
    s.NS.TriggerBinder.rejected[#s.NS.TriggerBinder.rejected + 1] = "GONE_EVENT"
    lines = section(s.NS, "rejected")
    assertTrue(has(lines, "rejected events OLD_EVENT"), shown(lines))
    -- red under: a rejected section that reads NS.rejectedEvents only.
    assertTrue(has(lines, "binder rejected events GONE_EVENT"), shown(lines))
end)

test("diagnostics: the state section says whether the old Outfitter is loaded", function()
    local s = scene()
    assertTrue(has(section(s.NS, "state"), "legacy Outfitter loaded=false"))
    s.NS.State.legacyLoaded = true
    -- red under: the state line hardwired to false.
    assertTrue(has(section(s.NS, "state"), "legacy Outfitter loaded=true"), shown(section(s.NS, "state")))
end)

test("diagnostics: the sections read state and never act", function()
    local s = scene()
    s.NS.Equip.__state.depth = 2
    enter(s, { name = "Ruins of Lordaeron", type = "arena", instanceID = 572 })
    local regs, timers = #s.M.__registrations(), #s.M.__timers()
    local sent = 0
    s.NS.NewBusTarget():RegisterMessage(s.NS.MSG.STACK_CHANGED, function() sent = sent + 1 end)
    for _, sec in ipairs(s.NS.Diagnostics.Sections()) do sec[2](recorder()) end
    assertEqual(#s.M.__registrations(), regs + 1, "only this case's own receiver")
    assertEqual(#s.M.__timers(), timers, "no timer")
    assertEqual(sent, 0, "no message")
    -- red under: an equip section that calls NS.Equip.Resume() (which zeroes the count) first.
    assertEqual(s.NS.Equip.__state.depth, 2, "the report does not clear the count")
end)

test("diagnostics: the report written to the console carries the zone and STUCK lines", function()
    local s = scene()
    enter(s, { name = "Ruins of Lordaeron", type = "arena", instanceID = 572 })
    s.NS.Equip.__state.depth = 2
    s.NS.DebugLog:RunDiagnostics()
    local D = s.NS.DebugLog
    assertTrue(D:FindLine("Instance: Ruins of Lordaeron (type arena, map ID 572)") ~= nil, "zone line")
    assertTrue(D:FindLine(STUCK) ~= nil, "STUCK line")
    assertTrue(D:FindLine("section") == nil or not D:CopyText():find("section %a+ failed"),
        "no section raised: " .. D:CopyText())
end)
