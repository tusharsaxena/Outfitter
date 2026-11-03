-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, design §2.1, §7.1; P3 C8
-- part). What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name at file load with this addon's read and write seams and its `of.*`
-- owner tokens; the profile's skin is applied right after AceDB exists and on every profile event;
-- Core's window edge is handed the owner; only this addon's own frames are painted, never the
-- character sheet's; and without the library the degraded facade answers every name the live one
-- carries, from a host copy of Ka0s Default that must equal the library's.
--
-- The rows and the Skin tab (the eight skin.* schema rows, one pick is one SetChoice) join at P4.23,
-- once settings/Schema.lua and settings/General.lua carry them. The factories handed the owner (the
-- dropdown, the context menu, the test strip) joined with core/WidgetsSetup.lua in C9.
--
-- Every case builds its own instance, so nothing leaks between cases.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "OutfitterReborn"
local BRAND = "Ka0s Outfitter Reborn"

-- Design §7.1: each owner token, the pixel the old addon drew, and the library role it follows.
local TOKENS = {
    ["of.outfit.disabled"] = { { 0.5, 0.5, 0.5, 1 }, "text.disabled" },
    ["of.outfit.missing"]  = { { 1, 0.1, 0.1, 1 }, "sem.bad" },
    ["of.outfit.banked"]   = { { 0.25, 0.2, 1.0, 1 }, "sem.info" },
    ["of.row.trigger"]     = { { 1, 1, 1, 1 }, "icon.tint" },
    ["of.slot.unknown"]    = { { 1, 0.82, 0, 1 }, "sem.statusWarn" },
    ["of.bar.worn"]        = { { 1, 0.82, 0, 1 }, "icon.hot" },
    ["of.dialog.error"]    = { { 1, 0.33, 0.33, 1 }, "sem.bad" },
}

local function near(a, b) return math.abs((a or 1) - (b or 1)) < 1e-6 end

local function assertColor(got, want, what)
    for i = 1, 4 do
        assertTrue(near(got[i], want[i]),
            ("%s[%d]: %s, want %s"):format(what, i, tostring(got[i]), tostring(want[i])))
    end
end

--- An enabled instance, its Skin major and a counter of this owner's looks changes.
local function setup(opts)
    local inst = T.load(opts)
    local NS, M = inst.NS, inst.mocks
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local counts = { looks = 0 }
    NS.Skin.OnLooksChanged(function() counts.looks = counts.looks + 1 end)
    return NS, M, Skin, counts
end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────────

test("skin seam: the owner is the folder name, and NS.Skin is its facade", function()
    -- red under: registering under the brand or a typo (the library keys every frame and every
    -- listener by owner), or publishing a facade of some other owner.
    local NS, _, Skin = setup()
    assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
    assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"" .. OWNER .. "\")")
    assertEqual(NS.Skin.owner, OWNER)
    assertEqual(Skin:OwnerLabel(OWNER), BRAND, "the copy confirmation names the addon by its brand")
end)

test("skin seam: the owner is registered at file load, before the profile store exists", function()
    -- skinning-§1: at FILE LOAD, so the EllesmereUI provider offers it before EllesmereUI dispatches.
    -- red under: RegisterOwner moved into OnInitialize or OnEnable.
    local inst = T.load({ init = false })
    assertTrue(inst.NS.db == nil, "nothing has run OnInitialize")
    assertTrue(inst.mocks.LibStub("LibKa0s-Skin-1.0"):IsOwner(OWNER), "not registered at file load")
end)

test("skin seam: the read answers Ka0s Default before the profile store exists", function()
    -- RegisterOwner calls `get` at FILE LOAD; a getter that raised there would be a Lua error on
    -- every login.
    local NS = T.load({ init = false }).NS
    local ok, source, skin = pcall(NS.SkinChoice)
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
    local font, texture = NS.SkinOverride()
    assertEqual(font, false); assertEqual(texture, false)
    -- And the write seam is a quiet no-op until settings/Schema.lua's NS.SetByPath exists.
    assertTrue(pcall(NS.WriteSkinChoice, "ka0s", "obsidian"), "the write raised without a store")
end)

test("skin seam: Core's window edge is handed the owner", function()
    -- skinning-§1: every library factory that takes an owner is given one. red under:
    -- NS.ApplySkin = lib.ApplySkin (an owner-less call draws Ka0s Default whatever the skin).
    local NS, M = setup()
    local core = M.LibStub("LibKa0s-Core-1.0")
    local real, seen = core.ApplySkin, nil
    core.ApplySkin = function(_, _, owner) seen = owner end
    local ok, err = pcall(NS.ApplySkin, M.CreateFrame("Frame"))
    core.ApplySkin = real
    if not ok then error(err, 0) end
    assertEqual(seen, OWNER)
end)

test("skin seam: the dropdown, the context menu and the test strip are handed the owner", function()
    -- skinning-§1: every library factory that takes an owner is given one. red under: dropping
    -- `owner = addonName` from MakeDropdown, showLevel or MakeTestStrip in core/WidgetsSetup.lua (the
    -- control then draws Ka0s Default whatever the skin).
    local NS, M = setup()
    local W = M.LibStub("LibKa0s-Widgets-1.0")
    local seen = {}
    local realDd, realMenu, realStrip = W.Dropdown, W.ContextMenu, W.TestStrip
    W.Dropdown = function(_, _, opts) seen.dropdown = opts and opts.owner end
    W.ContextMenu = function(_, _, opts) seen.menu = opts and opts.owner end
    W.TestStrip = function(_, opts) seen.strip = opts and opts.owner end
    local ok, err = pcall(function()
        NS.MakeDropdown(M.CreateFrame("Frame"), 100)
        NS.OpenMenu(M.CreateFrame("Frame"), function(root) root:CreateButton("probe", function() end) end)
        NS.MakeTestStrip(M.CreateFrame("Frame"), "probe")
    end)
    W.Dropdown, W.ContextMenu, W.TestStrip = realDd, realMenu, realStrip
    if not ok then error(err, 0) end
    assertEqual(seen.dropdown, OWNER, "MakeDropdown")
    assertEqual(seen.menu, OWNER, "OpenMenu")
    assertEqual(seen.strip, OWNER, "MakeTestStrip")
end)

test("skin seam: the test strip's End test stops test mode, and a caller's option wins", function()
    -- red under: dropping `onEnd` from core/WidgetsSetup.lua's MakeTestStrip (the strip takes no mouse),
    -- or copying the caller's opts before the defaults.
    local NS, M = setup()
    local W = M.LibStub("LibKa0s-Widgets-1.0")
    local seen, real = {}, W.TestStrip
    W.TestStrip = function(_, opts) seen[#seen + 1] = opts end
    local mine = function() end
    local ok, err = pcall(function()
        NS.MakeTestStrip(M.CreateFrame("Frame"), "probe")
        NS.MakeTestStrip(M.CreateFrame("Frame"), "probe", { onEnd = mine, kind = "sim" })
    end)
    W.TestStrip = real
    if not ok then error(err, 0) end
    assertEqual(seen[1].text, "probe")
    assertEqual(type(seen[1].onEnd), "function", "onEnd is passed")
    local active, stops = true, 0
    NS.Preview = { IsActive = function() return active end, Stop = function() stops = stops + 1; active = false end }
    seen[1].onEnd()
    seen[1].onEnd()
    NS.Preview = nil
    assertEqual(stops, 1, "End test stops an active test mode, and only an active one")
    assertTrue(seen[2].onEnd == mine, "the caller's onEnd did not win")
    assertEqual(seen[2].kind, "sim")
    assertEqual(seen[2].owner, OWNER)
end)

-- ── the profile: login and the profile events ────────────────────────────────────────────────────

test("skin seam: login applies the stored skin before anything is built", function()
    -- red under: no NS.ApplySkinChoice() in NS:OnInitialize (core/OutfitterReborn.lua). Until the
    -- schema seams exist the stored pair reads as Ka0s Default, so a choice applied before login
    -- must come back to it.
    local inst = T.load({ init = false })
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    inst.mocks.LibStub("AceAddon-3.0"):InitializeAddon(inst.NS)
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "OnInitialize did not apply the stored skin")
end)

test("skin seam: a profile switch applies the profile's skin", function()
    -- red under: no NS.ApplySkinChoice() in core/Database.lua's NS.OnProfileChanged.
    local NS, _, Skin, counts = setup()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    counts.looks = 0
    NS.db:SetProfile("SkinProbe")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "the switch did not apply the profile's skin")
    assertEqual(counts.looks, 1, "one switch, one repaint")
end)

-- ── the owner tokens ─────────────────────────────────────────────────────────────────────────────

test("skin seam: the owner tokens are exactly design §7.1's, namespaced of. and registered", function()
    -- skinning-§1/§9: addon-namespaced, never a library family. red under: a token the library
    -- refused (it answers nil through the facade), one named outside `of.`, or one added or dropped
    -- without the design.
    local NS, _, Skin = setup()
    local base = Skin:ResolveSkin("ka0s")
    local n = 0
    for name, def in pairs(NS.SKIN_TOKENS) do
        n = n + 1
        assertTrue(name:sub(1, 3) == "of.", name .. " is not in the of. namespace")
        assertTrue(TOKENS[name] ~= nil, name .. " is not a design §7.1 token")
        assertEqual(def.follow, TOKENS[name][2], name .. ": follow")
        assertTrue(type(base[def.follow]) == "table", name .. " follows " .. tostring(def.follow)
            .. ", which is no library color token")
        assertTrue(NS.Skin.Token(name) ~= nil, name .. " was refused by the library")
    end
    local want = 0
    for _ in pairs(TOKENS) do want = want + 1 end
    assertEqual(n, want, "the owner token count")
end)

test("skin seam: under Ka0s Default each owner token is the old addon's pixel", function()
    -- Never snapped to a near library token. red under: a `default` that drifts from INV §14/§7.2.
    local NS = setup()
    for name, row in pairs(TOKENS) do
        assertColor({ NS.Skin.Color(name) }, row[1], name)
    end
end)

test("skin seam: under another skin each owner token draws the role it follows", function()
    -- red under: a token registered without `follow`, which every skin then draws as Ka0s Default.
    local NS, _, Skin = setup()
    NS.ApplySkinChoice("ka0s", "obsidian")
    local obsidian = Skin:ResolveSkin("obsidian")
    for name, row in pairs(TOKENS) do
        local want = obsidian[row[2]]
        assertTrue(type(want) == "table", row[2] .. " is not an Obsidian token")
        assertColor({ NS.Skin.Color(name) }, { want[1], want[2], want[3], want[4] or 1 }, name .. " under Obsidian")
    end
end)

-- ── the helpers ──────────────────────────────────────────────────────────────────────────────────

test("skin seam: NS.SkinColor and NS.SkinEscape write a token the way a call site does", function()
    local NS = setup()
    assertEqual(select("#", NS.SkinColor("of.outfit.missing")), 3, "an opaque color is three components")
    assertEqual(NS.SkinEscape("of.outfit.missing"), "|cffff1a1a")
    assertEqual(NS.SkinEscape("title.text"), "|cffffd100")
    assertEqual(NS.SkinColor("no.such.token"), nil)
end)

test("skin seam: NS.QualityColor reads the q.* tokens and draws heirloom as artifact", function()
    -- INV §7.2: the old item rows mapped heirloom (7) to artifact (6). red under: dropping the map,
    -- or reading ITEM_QUALITY_COLORS before the skin's q.* token.
    local colors = {
        [4] = { r = 0.64, g = 0.21, b = 0.93 }, [6] = { r = 0.9, g = 0.8, b = 0.5 },
        [7] = { r = 0, g = 0.8, b = 1 },
    }
    local NS = setup({ mutate = function(m) m.ITEM_QUALITY_COLORS = colors end })
    local r, g, b = NS.QualityColor(7)
    assertTrue(near(r, 0.9) and near(g, 0.8) and near(b, 0.5), "heirloom is not drawn as artifact")
    local er, eg, eb = NS.Skin.Color("q.epic")
    local qr, qg, qb = NS.QualityColor(4)
    assertTrue(near(qr, er) and near(qg, eg) and near(qb, eb), "epic is not the skin's q.epic")
    assertEqual(NS.QualityColor(99), nil, "a quality with no color answers nil")
end)

-- ── only our frames ──────────────────────────────────────────────────────────────────────────────

-- A Blizzard frame handed to a painting call: NS.ApplySkin(…), NS.Skin.<Primitive>(…), S.<Primitive>(…)
-- or Skin:<Method>(…) whose first argument names the character sheet or another stock frame.
local BLIZZARD = { "CharacterFrame", "PaperDollFrame", "PaperDollItemsFrame", "Character%u%a*Slot",
                   "GameTooltip", "ShoppingTooltip%d", "StaticPopup%d" }

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "r"))
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
end

--- Every `file:line` in `sources` ({ rel = text }) that paints a Blizzard frame. Comments stripped.
local function blizzardPaints(sources)
    local out = {}
    for rel, text in pairs(sources) do
        local n = 0
        for line in (text .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            for call, arg in code:gmatch("([%w_%.:]+)%(%s*([%w_]+)") do
                local paints = call:match("ApplySkin$") or call:match("^NS%.Skin[%.:]%u")
                    or call:match("^S[%.:]%u") or call:match("^Skin:%u")
                if paints then
                    for _, pat in ipairs(BLIZZARD) do
                        if arg:match("^" .. pat .. "$") then out[#out + 1] = rel .. ":" .. n end
                    end
                end
            end
        end
    end
    table.sort(out)
    return out
end

test("skin seam: no authored file paints the character sheet or another Blizzard frame", function()
    -- skinning-§7, design §7.0 rule 3: the window docks beside the sheet and paints only its own
    -- frames. red under: NS.ApplySkin(CharacterFrame), NS.Skin.Shell(PaperDollFrame).
    local sources = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") then sources[rel] = readFile(rel) end
    end
    local hits = blizzardPaints(sources)
    assertEqual(#hits, 0, "Blizzard frames painted at " .. table.concat(hits, ", "))
end)

test("skin seam: the Blizzard-frame scan is falsifiable", function()
    local hits = blizzardPaints({
        ["modules/Planted.lua"] = table.concat({
            "NS.ApplySkin(CharacterFrame)",
            "NS.Skin.Shell(PaperDollFrame, {})",
            "S.Checkbox(CharacterHeadSlot)",
            "NS.ApplySkin(f) -- NS.ApplySkin(CharacterFrame) in prose",
            "S.Button(OutfitterRebornSheetButton)",
        }, "\n"),
    })
    assertEqual(table.concat(hits, ","), "modules/Planted.lua:1,modules/Planted.lua:2,modules/Planted.lua:3")
end)

-- ── the picker and the verb ──────────────────────────────────────────────────────────────────────

test("skin seam: the picker, the notice and the verb are quiet without the options seam", function()
    -- settings/OptionsSetup.lua (NS.Helpers) lands in C12; until then nothing shows and nothing
    -- raises, on every route the profile callbacks and OnEnable take.
    local NS = setup()
    assertEqual(NS.MaybeShowSkinPicker(), nil)
    assertTrue(pcall(NS.HideSkinPicker), "HideSkinPicker raised")
    local _, why = NS.MaybeShowSkinNotice()
    assertEqual(why, "unavailable")
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.owner, OWNER)
    assertTrue(rawequal(spec.get, NS.SkinChoice) and rawequal(spec.set, NS.WriteSkinChoice),
        "the spec reads and writes through the seam")
end)

test("skin seam: /of skin without the library prints the library-absent line", function()
    local NS = T.load({ libFiles = {} }).NS
    local said
    NS.Print = function(line) said = line end
    local win, why = NS.RunSkinVerb()
    assertEqual(win, nil); assertEqual(why, "absent")
    assertEqual(said, "/of skin is unavailable: the LibKa0s library did not load.")
end)

-- ── without the library ──────────────────────────────────────────────────────────────────────────

test("skin seam: the degraded facade answers every name the live facade carries", function()
    -- skinning-§1, testing-§8: without LibKa0s NS.Skin is a host table whose primitives are no-ops
    -- and whose Token / Color answer the host copy NS.SKIN_FALLBACK and the owner tokens' defaults.
    local live = T.load().NS
    local degraded = T.load({ libFiles = {} }).NS
    T.assertSurfaceParity(live.Skin, degraded.Skin, "Skin facade vs host stub", {})
    assertEqual(degraded.Skin.owner, OWNER)
    local r, g, b = degraded.SkinColor("of.outfit.banked")
    assertTrue(near(r, 0.25) and near(g, 0.2) and near(b, 1.0), "an owner token's default")
    assertEqual(degraded.SkinEscape("title.text"), "|cffffd100")
    assertEqual(degraded.ApplySkinChoice(), false, "nothing to apply without the library")
    assertEqual(degraded.SkinPaintAceTree({}), 0)
end)

test("skin seam: the degraded HudFont draws the face, a picked flag and no shadow", function()
    -- The one facade member that must draw. A no-op leaves a HUD string no face.
    local S = T.load({ libFiles = {} }).NS.Skin
    local drawn = {}
    local fs = {
        SetFont = function(_, face, size, flags) drawn.face, drawn.size, drawn.flags = face, size, flags end,
        SetShadowColor = function(_, _, _, _, a) drawn.shadowA = a end,
        SetShadowOffset = function(_, x, y) drawn.x, drawn.y = x, y end,
    }
    S.HudFont(fs, { face = "F.ttf", size = 14, flags = "THICKOUTLINE", shadow = false })
    assertEqual(drawn.face, "F.ttf")
    assertEqual(drawn.size, 14)
    assertEqual(drawn.flags, "THICKOUTLINE", "a picked flag draws as stored")
    assertEqual(drawn.x, 0, "the off arm clears the shadow")
    S.HudFont(fs, { face = "F.ttf", flags = "@skin", shadow = true })
    assertEqual(drawn.flags, "OUTLINE", "the sentinel never reaches SetFont")
    assertEqual(drawn.size, 12, "no size is Ka0s Default's HUD size")
    assertEqual(drawn.x, 1, "the stored shadow is still written on the string")
end)

test("skin seam: each host-copy skin token is the live library's Ka0s Default value", function()
    -- A copy that drifts from the library goes red here, so a degraded install draws Ka0s Default.
    local degraded = T.load({ libFiles = {} }).NS
    local M = T.load().mocks
    local live = M.LibStub("LibKa0s-Skin-1.0"):ResolveSkin("ka0s")
    local n = 0
    for name, c in pairs(degraded.SKIN_FALLBACK) do
        n = n + 1
        local want = live[name]
        assertTrue(type(want) == "table", name .. " is not a library color token")
        assertColor(c, want, name)
    end
    assertTrue(n > 0, "the host copy is empty")
end)
