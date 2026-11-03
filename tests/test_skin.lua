-- tests/test_skin.lua — the painted surfaces, built (P4.30; design §7.1, §9.5; skinning-§1, §3, §7).
--
-- What this pins beyond the seam (tests/test_skinsetup.lua) and the kit's skin pair
-- (tests/_kit/test_skin_switch.lua over tests/skin_surfaces.lua):
--   - the names: every `of.*` token a source file names is registered, every skin primitive a source
--     file calls is in the library's VOCAB (so the degraded facade answers it too), and every library
--     color a call site reads by name has a host copy in NS.SKIN_FALLBACK;
--   - only this addon's frames are painted: with every §9.5 surface built, no Blizzard frame is in the
--     skin's record, and the window, the dialogs, the icon chooser, the bar and the compare tooltips
--     each wear their own primitive (NS.ApplySkin's Shell, Panel, Tooltip);
--   - the icon rule (LibKa0s docs/api/README.md "Icon art: the rule"): Blizzard icon art in a window is
--     cropped at least 0.07 a side and edged with S.IconBorder{ fromSkin = true }, on the HUD bar with
--     { fromSkin = true, hud = true }, and no source file writes inline `|T` markup by hand;
--   - the two surfaces drawn at render follow a switch: an item row's quality-colored name (the window
--     re-renders after NS.Skin.OnLooksChanged) and a dialog's error line (`of.dialog.error`).
--
-- Every case builds its own instance through tests/skin_surfaces.lua, so nothing leaks between cases.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "OutfitterReborn"

local function surfaces() return dofile(T.root .. "/tests/skin_surfaces.lua")(T) end

local function readFile(rel)
    local f = assert(io.open(T.root .. "/" .. rel, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

--- The addon's own Lua sources the TOC loads, rel -> text (the vendored libraries left out).
local function sources()
    local out = {}
    for _, rel in ipairs(T.loadedAddonFiles) do
        if rel:match("%.lua$") and not rel:match("^libs/") then out[rel] = readFile(rel) end
    end
    return out
end

local function sorted(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

-- ── the names ───────────────────────────────────────────────────────────────────────────────────

-- Each line of `src` that is not a comment, with its number.
local function codeLines(src)
    local out, n = {}, 0
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        if not line:match("^%s*%-%-") then out[#out + 1] = { n = n, text = line:gsub("%-%-.*$", "") } end
    end
    return out
end

--- The skin primitives `srcs` call: NS.Skin.<Name>, and S.<Name>( in a file that binds S to NS.Skin.
local function primitivesCalled(srcs)
    local found = {}
    for rel, src in pairs(srcs) do
        local bindsS = src:find("local S = NS.Skin", 1, true) ~= nil
        for _, l in ipairs(codeLines(src)) do
            for name in l.text:gmatch("NS%.Skin%.(%u[%w]*)") do found[name] = found[name] or (rel .. ":" .. l.n) end
            if bindsS then
                for name in l.text:gmatch("%f[%w_]S%.(%u[%w]*)%(") do found[name] = found[name] or (rel .. ":" .. l.n) end
            end
        end
    end
    return found
end

test("skin: every owner token a source file names is registered", function()
    -- red under: a call site spelling "of.slot.unkown" (the library answers nil and the mark draws
    -- white), or a token dropped from NS.SKIN_TOKENS while a surface still paints with it.
    local NS = T.load().NS
    local missing, seen = {}, 0
    for rel, src in pairs(sources()) do
        for _, l in ipairs(codeLines(src)) do
            for name in l.text:gmatch('"(of%.[%w%.]+)"') do
                seen = seen + 1
                if not NS.SKIN_TOKENS[name] then missing[#missing + 1] = rel .. ":" .. l.n .. " " .. name end
            end
        end
    end
    assertTrue(seen >= 7, "the scan found only " .. seen .. " owner token names")
    assertEqual(#missing, 0, "unregistered owner tokens: " .. table.concat(missing, ", "))
end)

test("skin: every skin primitive a source file calls is in the library's VOCAB", function()
    -- The degraded facade is built from the same list, so a primitive outside it is a nil call the
    -- moment LibKa0s is missing. red under: a call site's NS.Skin.Pannel(f), or S.Glow(tex).
    local M = T.load().mocks
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local vocab = {}
    for _, name in ipairs(Skin.VOCAB) do vocab[name] = true end
    local facadeOnly = { Token = true, Color = true, Resolve = true, OnLooksChanged = true }
    local called = primitivesCalled(sources())
    local bad = {}
    for _, name in ipairs(sorted(called)) do
        if not (vocab[name] or facadeOnly[name]) then bad[#bad + 1] = name .. " (" .. called[name] .. ")" end
    end
    assertTrue(called.Button and called.IconBorder and called.Mark, "the scan found none of the window's primitives")
    assertEqual(#bad, 0, "primitives outside VOCAB: " .. table.concat(bad, ", "))
    local degraded = T.load({ libFiles = {} }).NS.Skin
    for name in pairs(called) do
        assertEqual(type(degraded[name]), "function", "the degraded facade has no " .. name)
    end
end)

test("skin: the primitive scan is falsifiable", function()
    local found = primitivesCalled({
        ["modules/A.lua"] = "local S = NS.Skin\nS.Pannel(f)\n-- S.Ghost(f)\nNS.Skin.Mark(t)",
        ["modules/B.lua"] = "local S = other\nS.NotSkin(f)\nLS.Button(f)",
    })
    assertEqual(table.concat(sorted(found), ","), "Mark,Pannel")
end)

test("skin: every library color a call site reads by name has a host copy", function()
    -- Without LibKa0s, NS.SkinColor answers NS.SKIN_FALLBACK, so a token missing there hands
    -- SetTextColor nil. red under: dropping "text.muted" from NS.SKIN_FALLBACK (modules/Window_Rows.lua
    -- and modules/Tooltips_Compare.lua read it).
    local NS = T.load({ libFiles = {} }).NS
    local missing, seen = {}, 0
    for rel, src in pairs(sources()) do
        for _, l in ipairs(codeLines(src)) do
            for name in l.text:gmatch('NS%.Skin[%w]*%("([%w]+%.[%w%.]+)"') do
                if not name:match("^of%.") then
                    seen = seen + 1
                    local r = NS.SkinColor(name)
                    if type(r) ~= "number" then missing[#missing + 1] = rel .. ":" .. l.n .. " " .. name end
                end
            end
        end
    end
    assertTrue(seen >= 3, "the scan found only " .. seen .. " library color names")
    assertEqual(#missing, 0, "no host copy for: " .. table.concat(missing, ", "))
end)

-- ── only our frames ─────────────────────────────────────────────────────────────────────────────

-- The Blizzard frames the docked surfaces sit on, beside or over (skinning-§7: never painted).
local BLIZZARD = { "CharacterFrame", "PaperDollFrame", "CharacterFrameCloseButton", "UIParent", "GameTooltip",
                   "ShoppingTooltip1", "ShoppingTooltip2", "MerchantFrame", "PaperDollItemsFrame" }

--- Every §9.5 surface built on one instance: answers NS, M, the Skin major and the built objects.
local function buildAll()
    local facts = surfaces()
    local built = {}
    for _, s in ipairs(facts.surfaces) do built[s.name] = s.build() end
    local NS, M = facts.live()
    return NS, M, M.LibStub("LibKa0s-Skin-1.0"), built
end

test("skin: with every surface built, no Blizzard frame is painted", function()
    -- red under: NS.Skin.Panel(CharacterFrame) in modules/SlotEnables.lua's Build, or a slot checkbox
    -- painted on its Character<Slot> anchor rather than on itself.
    local NS, M, Skin = buildAll()
    local painted = {}
    local names = {}
    for _, n in ipairs(BLIZZARD) do names[#names + 1] = n end
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do names[#names + 1] = "Character" .. slot end
    for _, n in ipairs(names) do
        local f = M[n]
        if f ~= nil and Skin.painted[f] ~= nil then painted[#painted + 1] = n end
    end
    assertEqual(#painted, 0, "Blizzard frames in the skin's record: " .. table.concat(painted, ", "))
    local n = 0
    for _ in pairs(Skin.byOwner[OWNER] or {}) do n = n + 1 end
    assertTrue(n > 50, "the surfaces painted only " .. n .. " objects for the owner")
end)

-- The primitive each owned frame wears: what the frame's record calls it.
local SHELLS = {
    { "the window's shell", "Shell" },
    { "the outfit dialog's shell", "Shell" },
    { "the trigger dialog's shell", "Shell" },
    { "the rebuild dialog's shell", "Shell" },
    { "the progress dialog's shell", "Shell" },
    { "the icon chooser's shell", "Panel" },
    { "the bar's backplate", "Panel" },
    { "a compare tooltip", "Tooltip" },
}

test("skin: the window and the dialogs wear NS.ApplySkin's Shell, the chooser and bar a Panel", function()
    -- red under: NS.ApplySkin dropped from modules/UIDialogs.lua's chrome (a dialog keeps Core's
    -- fixed edge), S.Panel(f, { popup = true }) dropped from the icon chooser, S.Tooltip from a
    -- compare tooltip.
    local _, _, Skin, built = buildAll()
    for _, pair in ipairs(SHELLS) do
        local f = assert(built[pair[1]], pair[1] .. " was not built")
        local rec = Skin.painted[f]
        assertTrue(rec ~= nil and rec.owner == OWNER, pair[1] .. " is not painted for " .. OWNER)
        assertTrue(rec.calls[pair[2]] ~= nil, pair[1] .. " does not wear " .. pair[2])
    end
    local chooser = Skin.painted[built["the icon chooser's shell"]].calls.Panel[1]
    assertTrue(type(chooser) == "table" and chooser.popup == true, "the icon chooser is not a popup panel")
end)

-- ── the icon rule ───────────────────────────────────────────────────────────────────────────────

--- The IconBorder options recorded on `target`, or nil.
local function iconBorder(Skin, target)
    local rec = Skin.painted[target]
    local call = rec and rec.calls.IconBorder
    return call and (call[1] or {}) or nil
end

local function assertCropped(tex, what)
    local c = { tex:GetTexCoord() }
    assertTrue(type(c[1]) == "number" and c[1] >= 0.07 - 1e-6 and c[2] >= 0.07 - 1e-6, what .. ": not cropped at the top left")
    assertTrue(c[7] <= 0.93 + 1e-6 and c[8] <= 0.93 + 1e-6, what .. ": not cropped at the bottom right")
end

test("skin: Blizzard icon art in a window is cropped and edged from the skin, never as a HUD", function()
    -- red under: S.IconBorder(row.icon) without fromSkin, or with hud = true (a window's icon wears
    -- icon.outline, the HUD's icon.border never), or zoom = false on the icon chooser's grid.
    local NS, _, Skin, built = buildAll()
    local itemRow = built["an item row"]
    local grid = built["an icon chooser grid button"]
    for what, tex in pairs({ ["an item row's icon"] = itemRow.icon, ["a grid button's icon"] = grid.icon }) do
        local o = iconBorder(Skin, tex)
        assertTrue(o ~= nil, what .. " has no S.IconBorder")
        assertEqual(o.fromSkin, true, what .. ": fromSkin")
        assertTrue(o.hud ~= true, what .. " is edged as a HUD icon")
        assertCropped(tex, what)
    end
    assertTrue(NS.WindowRows.rows[1] ~= nil, "the rows were built")
end)

test("skin: the bar's icons are HUD icons, cropped and edged from the skin", function()
    -- red under: modules/Bar_Buttons.lua's S.IconBorder(btn, { hud = true }) without fromSkin, or
    -- without hud (the bar would wear a window's icon.outline), or S.SquareIcon without crop.
    local _, _, Skin, built = buildAll()
    local btn = built["a bar button"]
    local o = iconBorder(Skin, btn)
    assertTrue(o ~= nil, "the bar button has no S.IconBorder")
    assertEqual(o.hud, true, "hud")
    assertEqual(o.fromSkin, true, "fromSkin")
    assertCropped(btn.icon, "a bar button's icon")
end)

test("skin: the sheet button's logo is a cropped square icon", function()
    -- red under: modules/Dock.lua's NS.Skin.SquareIcon(button) without crop (the logo's art edge shows).
    local _, _, Skin, built = buildAll()
    local btn = built["the sheet button"]
    local call = Skin.painted[btn].calls.SquareIcon
    assertTrue(call ~= nil and type(call[1]) == "table" and call[1].crop == true, "S.SquareIcon(btn, { crop = true })")
    assertCropped(btn.icon, "the sheet button's logo")
end)

--- The lines of `srcs` that write inline texture markup by hand (a "|T" in a string).
local function handMarkup(srcs)
    local out = {}
    for rel, src in pairs(srcs) do
        for _, l in ipairs(codeLines(src)) do
            if l.text:find("|T", 1, true) then out[#out + 1] = rel .. ":" .. l.n end
        end
    end
    table.sort(out)
    return out
end

test("skin: no source file writes inline icon markup by hand (W.IconText crops it)", function()
    -- The rule's inline row: `|T` markup is cropped 5..59 of 64 only through W.IconText.
    -- red under: a tooltip line built as "|T" .. icon .. ":14|t".
    local hits = handMarkup(sources())
    assertEqual(#hits, 0, "hand-written |T markup at " .. table.concat(hits, ", "))
    assertEqual(table.concat(handMarkup({ ["modules/P.lua"] = 'x = "|T" .. icon\n-- "|T" in prose\nok()' }), ","),
        "modules/P.lua:1", "the scan is falsifiable")
end)

-- ── the surfaces drawn at render ────────────────────────────────────────────────────────────────

local function textColor(M, fs)
    local c = M.__paint(fs).textColor
    return c and c[1], c and c[2], c and c[3]
end

--- Every shipped skin but Ka0s Default, then Ka0s Default again: a walk of real switches.
local function walk(Skin)
    local keys = {}
    for _, def in ipairs(Skin:Skins()) do
        if def.key ~= "ka0s" then keys[#keys + 1] = def.key end
    end
    keys[#keys + 1] = "ka0s"
    assertTrue(#keys > 2, "too few shipped skins to switch through")
    return keys
end

test("skin: a switch recolors a dialog's error line through of.dialog.error", function()
    -- red under: modules/UIDialogs.lua's ErrorLine writing NS.SkinColor once with SetTextColor (it
    -- keeps Ka0s Default's red under every skin).
    local NS, M, Skin, built = buildAll()
    local fs = built["a dialog's error line"]
    local r, g, b = textColor(M, fs)
    assertTrue(near(r, 1) and near(g, 0.33) and near(b, 0.33), "Ka0s Default draws the old addon's red")
    -- No shipped skin moves sem.bad's follower, so the walk ends on the kit's probe skin, which gives
    -- every token a value of its own (tests/_kit/skin_switch.lua).
    local W = dofile(T.root .. "/tests/_kit/skin_switch.lua")
    Skin:RegisterSkin({ key = W.PROBE_KEY, label = "Probe", tokens = W.probeTokens(Skin) })
    local keys = walk(Skin)
    keys[#keys + 1] = W.PROBE_KEY
    local moved = false
    for _, key in ipairs(keys) do
        Skin:SetChoice(OWNER, "ka0s", key)
        local wr, wg, wb = NS.Skin.Color("of.dialog.error")
        r, g, b = textColor(M, fs)
        assertTrue(near(r, wr) and near(g, wg) and near(b, wb), key .. ": the error line is not of.dialog.error")
        if not (near(r, 1) and near(g, 0.33) and near(b, 0.33)) then moved = true end
    end
    assertTrue(moved, "no skin moved of.dialog.error, so the walk proved nothing")
end)

test("skin: a switch marks the window, and its next tick recolors an item row's name", function()
    -- red under: modules/Window.lua without its NS.Skin.OnLooksChanged listener (an item's name keeps
    -- the last skin's quality color until something else dirties the list).
    local NS, M, Skin = buildAll()
    NS.Window.Render()
    local row
    for _, r in ipairs(NS.WindowRows.rows) do
        if row == nil and r.entry and r.entry.kind == "item" then row = r end
    end
    assertTrue(row ~= nil, "no item row is shown")
    local moved = false
    for _, key in ipairs(walk(Skin)) do
        assertEqual(NS.Window.dirty, false, key .. ": the list was dirty before the switch")
        local br, bg, bb = textColor(M, row.itemName)
        Skin:SetChoice(OWNER, "ka0s", key)
        assertEqual(NS.Window.dirty, true, key .. ": the switch did not mark the list")
        NS.Window.RenderIfDirty()
        local r, g, b = NS.QualityColor(row.entry.item.quality)
        if r == nil then r, g, b = NS.SkinColor("text.muted") end
        local nr, ng, nb = textColor(M, row.itemName)
        assertTrue(near(nr, r) and near(ng, g) and near(nb, b), key .. ": the name is not the skin's quality color")
        if not (near(nr, br) and near(ng, bg) and near(nb, bb)) then moved = true end
    end
    assertTrue(moved, "no shipped skin moved the item's quality color, so the walk proved nothing")
end)
