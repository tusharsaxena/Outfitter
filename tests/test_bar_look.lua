-- tests/test_bar_look.lua — the outfit bar's look (modules/Bar_Chrome.lua): the label's font and
-- color through the skin seam, the border color's skin companion on the player's plate and icon edge,
-- and test mode without the library. Split out of tests/test_bar.lua by the smoke round 2 review
-- fixes, to keep that suite under the 1000-line file budget; it shares tests/bar_scene.lua.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local H = dofile(T.root .. "/tests/bar_scene.lua")(T)
local scene, complete, accessory, settle, point = H.scene, H.complete, H.accessory, H.settle, H.point

--- LibSharedMedia's path for font `key` in the mock, or nil.
local function fontPath(M, key)
    local LSM = M.LibStub("LibSharedMedia-3.0", true)
    return type(key) == "string" and LSM:Fetch("font", key, true) or nil
end

test("bar: a label draws through S.HudFont with its font block, and its color follows the skin until told not to", function()
    local NS, M, Bar = scene()
    complete(NS, "A")
    local S = NS.Skin
    local seen
    local realFont = S.HudFont
    S.HudFont = function(fs, opts) seen = opts; return realFont(fs, opts) end
    NS.SetByPath("bar.labels.fontSize", 14)
    -- A swatch unlike the skin's gold, so the color check below tells the two apart.
    NS.SetByPath("bar.labels.fontColor", { r = 0.1, g = 0.2, b = 0.3, a = 1 })
    settle(M)
    S.HudFont = realFont
    -- red under: a label painted with a plain SetFont (skinning-§6: HUD text draws through S.HudFont)
    assertTrue(seen ~= nil, "S.HudFont was not called")
    assertEqual(seen.flags, "@skin", "the flags From skin")
    assertEqual(seen.size, S.HudFontSize(14, true), "the size through S.HudFontSize")
    assertEqual(seen.shadowFromSkin, true)
    assertEqual(seen.face, fontPath(M, S.Token("hud.font")), "the skin's face while Use the skin's font is on")
    local r, g, b = Bar.Label(1):GetTextColor()
    local sr, sg, sb = S.HudLabelColor()
    -- red under: labelColor drawing the swatch while fontColorFromSkin is on
    assertTrue(r == sr and g == sg and b == sb, "the skin's HUD label color")
    assertFalse(r == 0.1 and g == 0.2 and b == 0.3, "not the swatch")
    NS.SetByPath("bar.labels.fontColorFromSkin", false)
    settle(M)
    r, g, b = Bar.Label(1):GetTextColor()
    -- red under: the swatch never read (the label always in the skin's color)
    assertTrue(r == 0.1 and g == 0.2 and b == 0.3, "the swatch")
end)

test("bar: the player's plate and icon edge take the skin's border color while that companion stays on", function()
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    NS.SetByPath("bar.bgFromSkin", false)
    NS.SetByPath("bar.frame.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    NS.SetByPath("bar.icons.borderStyleFromSkin", false)
    NS.SetByPath("bar.icons.borderColor", { r = 1, g = 0, b = 0, a = 1 })
    settle(M)
    assertEqual(NS.GetSetting("bar.frame.borderColorFromSkin"), true, "the default follows the skin")
    assertEqual(NS.GetSetting("bar.icons.borderColorFromSkin"), true, "the default follows the skin")
    local f = Bar.Frame()
    assertTrue(f.plate:IsShown(), "the player's plate")
    local function same(label, got, want)
        assertTrue(want[1] ~= nil, label .. ": the skin answers the token")
        assertTrue(got[1] == want[1] and got[2] == want[2] and got[3] == want[3], label .. ": the skin's color")
        assertFalse(got[1] == 1 and got[2] == 0 and got[3] == 0, label .. ": not the swatch")
    end
    -- red under: Bar.EdgeColor reading the swatch whatever borderColorFromSkin says
    same("plate", { f.plate:GetBackdropBorderColor() }, { NS.Skin.Color("bar.border") })
    local btn = Bar.Buttons()[1]
    assertTrue(btn.edge ~= nil and btn.edge:IsShown(), "the player's icon edge")
    same("icon", { btn.edge:GetBackdropBorderColor() }, { NS.Skin.Color("icon.border") })
end)

test("bar: without the library test mode reserves no strip room, and the header title says test mode", function()
    local inst = T.load({ libFiles = {} })
    local NS, M = inst.NS, inst.mocks
    dofile(T.root .. "/tests/_kit/mock_paint.lua")(M)
    H.recordGeometry(M)
    local on = true
    T.fake(NS, "Dock", { IsShown = function() return false end, Suspend = true, Resume = true })
    local preview = T.fake(NS, "Preview", { IsActive = function() return on end, Suspend = true, Resume = true })
    rawset(preview, "Source", { Rows = function() return { { categoryID = "Complete", outfits = {
        { id = "preview:1", name = "Test Outfit 1", icon = 132276, placeholder = true } } } } end })
    NS.Bar.Resume()
    M.__fireTimers()
    local f = NS.Bar.Frame()
    assertTrue(f ~= nil and f:IsShown(), "test mode shows the bar")
    assertEqual(f.strip, false, "no strip without the library")
    local row = point(NS.Bar.Buttons()[1]:GetParent())
    -- red under: Render told a strip shows (HeaderHeight(true)) when MakeTestStrip answered nil
    assertEqual(row[5], -(NS.Bar.HeaderHeight() + NS.GetSetting("bar.layout.padding")), "no gap for a strip not drawn")
    -- red under: no marker at all (preview-mode: the header word stands where no strip shows)
    assertEqual(f.title:GetText(), "Outfits (test mode)")
    on = false
    NS.db.profile.bar.shown = true
    NS.Bar.Refresh()
    assertEqual(f.title:GetText(), "Outfits", "the live bar's title")
end)

test("bar: with Ignore fonts on a label draws its own stored face, the seam's answer", function()
    local NS, M = scene()
    complete(NS, "A")
    local S = NS.Skin
    local seen
    local realFont = S.HudFont
    S.HudFont = function(fs, opts) seen = opts; return realFont(fs, opts) end
    NS.SetByPath("skin.ignoreFonts", true)
    NS.SetByPath("bar.labels.fontSize", 13)
    settle(M)
    S.HudFont = realFont
    NS.SetByPath("skin.ignoreFonts", false)
    assertEqual(NS.GetSetting("bar.labels.fontFromSkin"), true, "Use the skin's font stays on")
    local want = fontPath(M, NS.GetSetting("bar.labels.font"))
    assertTrue(want ~= nil, "the stored face is registered")
    -- red under: a face resolved around S.Resolve (nil while it follows the skin, so the client's font)
    assertTrue(seen ~= nil, "S.HudFont was not called")
    assertEqual(seen.face, want, "the stored pick, as skinning-§6 has the seam answer it")
end)

test("bar: a button's edges, worn edge and worn mark stand on named rungs, the mark on a mouse-off overlay", function()
    local NS, M, Bar = scene()
    local hat = accessory(NS, "Hat")
    NS.Stack.Wear(hat, { hw = true })
    NS.SetByPath("bar.icons.borderStyleFromSkin", false)
    settle(M)
    local LEVEL = NS.Constants.LAYERS.LEVEL
    -- frame-layering-§3: BORDER < the worn edge < OVERLAY, every rung named in LAYERS.LEVEL
    assertTrue(LEVEL.BAR_EDGE < LEVEL.BAR_WORN_EDGE and LEVEL.BAR_WORN_EDGE < LEVEL.BAR_OVERLAY, "the rung order")
    local btn = Bar.Buttons()[1]
    local base = btn:GetFrameLevel()
    assertTrue(btn.edge ~= nil and btn.wornEdge ~= nil and btn.overlay ~= nil, "the three child frames")
    -- red under: backdropFrame's bare 1 and 2, and the mark left on the button under its child frames
    assertEqual(btn.skinEdge:GetFrameLevel(), base + LEVEL.BAR_EDGE, "the skin's edge")
    assertEqual(btn.edge:GetFrameLevel(), base + LEVEL.BAR_EDGE, "the player's edge")
    assertEqual(btn.wornEdge:GetFrameLevel(), base + LEVEL.BAR_WORN_EDGE, "the worn edge")
    assertEqual(btn.overlay:GetFrameLevel(), base + LEVEL.BAR_OVERLAY, "the overlay")
    assertTrue(btn.worn:GetParent() == btn.overlay, "the worn mark on the overlay")
    assertEqual(rawget(btn.overlay, "__mouse"), false, "the overlay passes the mouse through")
    assertTrue(btn.worn:IsShown() and btn.wornEdge:IsShown(), "both show for a worn outfit")
end)

--- Whether the library drew a shown edge ring on `frame` (its record's holder and top edge).
local function libEdgeShown(Skin, frame)
    local rec = Skin.painted[frame]
    local h = rec and rec.regions.holder
    local top = rec and rec.regions.edgeTop
    return h ~= nil and h:IsShown() == true and top ~= nil and top:IsShown() == true
end

test("bar: Icons > Show border draws the skin's icon edge when on and no edge at all when off, in every skin", function()
    -- Smoke round 3 E5 (screens 21-23): S.SquareIcon on the button drew a second, permanent edge in
    -- the window outline (icon.outline) that Show border never reached, so off still showed a border
    -- (Ka0s Default's gray outline: on looked off) and on drew one over it (every other skin: no change).
    -- red under: modules/Bar_Buttons.lua's S.SquareIcon(btn, { crop = true }) back in NewButton.
    local NS, M, Bar = scene()
    accessory(NS, "Hat")
    settle(M)
    local Skin = M.LibStub("LibKa0s-Skin-1.0")
    local keys = {}
    for _, def in ipairs(Skin:Skins()) do keys[#keys + 1] = def.key end
    assertTrue(#keys > 2, "too few shipped skins to switch through")
    for _, key in ipairs(keys) do
        NS.ApplySkinChoice("ka0s", key)
        for _, on in ipairs({ true, false }) do
            NS.SetByPath("bar.icons.borderShow", on)
            settle(M)
            local btn = Bar.Buttons()[1]
            local what = key .. (on and " on" or " off")
            assertFalse(libEdgeShown(Skin, btn), what .. ": an edge on the button outside the Border block")
            assertEqual(btn.skinEdge:IsShown() == true, on, what .. ": the skin's icon edge")
            assertTrue(libEdgeShown(Skin, btn.skinEdge), what .. ": the skin's edge is drawn on its frame")
        end
    end
    NS.ApplySkinChoice("ka0s", "ka0s")
    -- The art's own border stays trimmed without S.SquareIcon's crop.
    local c = { Bar.Buttons()[1].icon:GetTexCoord() }
    assertTrue(c[1] >= 0.07 and c[7] <= 0.93, "the icon is cropped")
end)
