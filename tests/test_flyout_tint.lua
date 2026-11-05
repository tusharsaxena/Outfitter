-- tests/test_flyout_tint.lua — the equipment flyout's border tint (smoke round 3 E1; the accepted
-- deviation DEV-SKIN-FLYOUT-TINT, skinning-§7, docs/ARCHITECTURE.md -> Documented deviations).
--
-- While the outfit window is on screen and the flyout is open on one of the 18 character-sheet slots
-- (this addon holds it), modules/QuickSlots.lua tints the flyout's rim textures with the skin's
-- `win.border`: vertex color, desaturated so the hue is the token's. It gives Blizzard's own color
-- and desaturation back, exactly as it read them, when the window closes, when another host (Item
-- Upgrade, Item Interaction, Runeforge) opens the flyout, and at the stand-down; a skin change
-- re-tints; nothing is written in combat lockdown.
--
-- THE CLIENT STAND-IN, at wow-ui-source@297d7aa (Blizzard_FrameXML): the rim is the
-- UI-GearManager-Flyout art, `buttonFrame.bg1` (EquipmentFlyout.xml:61-69) plus the `bg2..bgN` that
-- `_createFlyoutBG` adds as a page needs them (EquipmentFlyout.lua:121-135, used at :345-431), and
-- `NavigationFrame.BottomBackground` (xml:83-86), the paging bar's strip of the same art. The flyout's
-- `Highlight` (xml:41-51) is the open slot's glow, not the rim, and is never tinted. Each texture
-- records its vertex color and desaturation; each starts at a color of its own, so a restore that
-- wrote white back instead of what it read would fail. EquipmentFlyout_UpdateItems makes the
-- textures a page needs (`state.bgs`), as Blizzard's does, and the instance post-hooks it by name.
-- The window is a recorded fake (NS.Dock.IsVisible); its show and hide reach QuickSlots through
-- DrawerSync, as Dock's OnShow / OnHide do.

local T = _G.OUTFITTERREBORN_TEST
local unitLoad = dofile(T.root .. "/tests/unit_load.lua")(T)
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "OutfitterReborn"

-- A rim texture: a vertex color and a desaturation, each read back as set, and its writes counted.
local function texture(r, g, b, a, desat)
    local t = { color = { r, g, b, a }, desat = desat == true, writes = 0 }
    function t:SetVertexColor(cr, cg, cb, ca)
        self.color = { cr, cg, cb, ca == nil and 1 or ca }
        self.writes = self.writes + 1
    end
    function t:GetVertexColor() return self.color[1], self.color[2], self.color[3], self.color[4] end
    function t:SetDesaturated(on) self.desat = on == true; self.writes = self.writes + 1 end
    function t:IsDesaturated() return self.desat end
    return t
end

-- A distinct starting color per texture, so a restore is checked against what each one carried.
local seed = 0
local function freshTexture()
    seed = seed + 1
    return texture(1 - seed / 100, 1, 1 - seed / 200, 1, seed % 3 == 0)
end

local function snapshot(t) return { t.color[1], t.color[2], t.color[3], t.color[4], tostring(t.desat) } end

local function sameAs(t, snap, msg)
    assertEqual(table.concat(snapshot(t), ","), table.concat(snap, ","), msg)
end

-- An instance with Blizzard's flyout stand-in and a fake window, the hooks built.
local function tintInstance()
    local state = { visible = false, bgs = 1 }
    local inst = unitLoad({ mutate = function(M)
        local flyout = M.CreateFrame("Frame", "EquipmentFlyoutFrame", M.UIParent)
        flyout:Hide()
        -- The item frame the drawer anchors (QuickSlots' placeFlyout); its points are not this suite's.
        flyout.buttonFrame = { numBGs = 1, bg1 = freshTexture(),
                               ClearAllPoints = function() end, SetPoint = function() end }
        flyout.NavigationFrame = { BottomBackground = freshTexture() }
        flyout.Highlight = freshTexture()
        -- Blizzard's update makes the background pieces a page needs (EquipmentFlyout.lua:121-135).
        M.EquipmentFlyout_UpdateItems = function()
            local bf = flyout.buttonFrame
            while bf.numBGs < state.bgs do
                bf.numBGs = bf.numBGs + 1
                bf["bg" .. bf.numBGs] = freshTexture()
            end
        end
        local base = M.hooksecurefunc
        M.hooksecurefunc = function(a, b, c)
            if type(a) == "string" then
                local orig = rawget(M, a)
                if type(orig) ~= "function" then error("hooksecurefunc(): " .. a .. " is not a function", 2) end
                rawset(M, a, function(...) orig(...); b(...) end)
                return
            end
            return base(a, b, c)
        end
    end })
    local NS, M = inst.NS, inst.mocks
    NS.Dock.IsVisible = function() return state.visible end
    NS.QuickSlots.Resume()
    return NS, M, state
end

-- Every rim texture the flyout has now: the background pieces and the paging strip.
local function rim(M)
    local f = M.EquipmentFlyoutFrame
    local out = {}
    for i = 1, f.buttonFrame.numBGs do out[#out + 1] = f.buttonFrame["bg" .. i] end
    out[#out + 1] = f.NavigationFrame.BottomBackground
    return out
end

local function snapshots(M)
    local out = {}
    for i, t in ipairs(rim(M)) do out[i] = snapshot(t) end
    return out
end

-- The client opening the flyout on `button`: it is set, shown and its items placed.
local function openOn(M, button)
    local f = M.EquipmentFlyoutFrame
    f.button = button
    f:Show()
    M.EquipmentFlyout_UpdateItems()
end

local function setWindow(NS, state, visible)
    state.visible = visible
    NS.QuickSlots.DrawerSync()
end

local function border(NS)
    local r, g, b, a = NS.Skin.Color("win.border")
    return { r, g, b, a == nil and 1 or a }
end

local function tintedWith(t, c, msg)
    assertTrue(t.desat, msg .. ": not desaturated")
    assertEqual(table.concat(t.color, ","), table.concat(c, ","), msg .. ": not the skin's border color")
end

-- A skin whose win.border is not the one applied now, or nil.
local function otherSkin(NS, Skin)
    local now = table.concat(border(NS), ",")
    for _, def in ipairs(Skin:Skins()) do
        Skin:SetChoice(OWNER, "ka0s", def.key)
        if table.concat(border(NS), ",") ~= now then return def.key end
    end
    return nil
end

test("flyout tint: with the window open a sheet slot's flyout rim takes the skin's border color", function()
    local NS, M, state = tintInstance()
    state.bgs = 3
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    local c = border(NS)
    -- red under: no tint in the UpdateItems post-hook (the rim keeps Blizzard's gold).
    for i, t in ipairs(rim(M)) do tintedWith(t, c, "rim texture " .. i) end
    assertEqual(#rim(M), 4, "three background pieces and the paging strip")
    assertEqual(M.EquipmentFlyoutFrame.Highlight.writes, 0, "the slot's glow is not the rim")
end)

test("flyout tint: the window's close gives each texture back exactly what it had", function()
    local NS, M, state = tintInstance()
    state.bgs = 2
    M.EquipmentFlyout_UpdateItems()
    local before = snapshots(M)
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.LegsSlot)
    setWindow(NS, state, false)
    -- red under: no restore on the window's hide, or a restore that writes white over what was read.
    for i, t in ipairs(rim(M)) do sameAs(t, before[i], "rim texture " .. i .. " after the close") end
end)

test("flyout tint: with the window closed the flyout keeps Blizzard's rim", function()
    local NS, M, state = tintInstance()
    setWindow(NS, state, false)
    openOn(M, M.__slotButtons.HeadSlot)
    -- red under: a tint gate without the window (the stock sheet's flyout would wear the skin).
    for i, t in ipairs(rim(M)) do assertEqual(t.writes, 0, "rim texture " .. i .. " was written") end
end)

test("flyout tint: opening the window over an open flyout tints it", function()
    local NS, M, state = tintInstance()
    openOn(M, M.__slotButtons.HeadSlot)
    setWindow(NS, state, true)
    -- red under: no tint from DrawerSync (only the next flyout update would tint it).
    for i, t in ipairs(rim(M)) do tintedWith(t, border(NS), "rim texture " .. i) end
end)

test("flyout tint: another host's flyout gets Blizzard's rim back", function()
    local NS, M, state = tintInstance()
    local before = snapshots(M)
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    -- Item Upgrade's own slot button, not one of the sheet's 18 (EquipmentFlyout.lua:244).
    local host = M.CreateFrame("Frame", nil, M.UIParent)
    host.flyoutSettings = {}
    local foreign = M.CreateFrame("Button", nil, host)
    openOn(M, foreign)
    -- red under: a tint gate that reads only the window (every host's flyout would wear the skin).
    for i, t in ipairs(rim(M)) do sameAs(t, before[i], "rim texture " .. i .. " under another host") end
end)

test("flyout tint: a page that adds a background piece tints it, and the close restores it too", function()
    local NS, M, state = tintInstance()
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    -- The next page needs bg2 and bg3: Blizzard makes them on this update, each its own color first.
    local bf = M.EquipmentFlyoutFrame.buttonFrame
    bf.numBGs = 3
    bf.bg2, bf.bg3 = freshTexture(), freshTexture()
    local made = { [2] = snapshot(bf.bg2), [3] = snapshot(bf.bg3) }
    M.EquipmentFlyout_UpdateItems()
    -- red under: a tint that only wrote the textures it saw first (bg2, bg3 keep Blizzard's gold).
    tintedWith(bf.bg2, border(NS), "bg2")
    tintedWith(bf.bg3, border(NS), "bg3")
    setWindow(NS, state, false)
    sameAs(bf.bg2, made[2], "bg2 after the close")
    sameAs(bf.bg3, made[3], "bg3 after the close")
end)

test("flyout tint: a skin change re-tints, and the close still restores Blizzard's color", function()
    local NS, M, state = tintInstance()
    local Skin = M.LibStub("LibKa0s-Skin-1.0", true)
    assertTrue(Skin ~= nil, "the skin library is vendored")
    local before = snapshots(M)
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    local key = otherSkin(NS, Skin)
    assertTrue(key ~= nil, "no shipped skin has a different win.border, so the case proves nothing")
    -- red under: no NS.Skin.OnLooksChanged listener (the rim keeps the last skin's border).
    for i, t in ipairs(rim(M)) do tintedWith(t, border(NS), key .. ": rim texture " .. i) end
    setWindow(NS, state, false)
    -- red under: a re-tint that read the tinted color as Blizzard's.
    for i, t in ipairs(rim(M)) do sameAs(t, before[i], key .. ": rim texture " .. i .. " after the close") end
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
end)

test("flyout tint: the stand-down restores the rim, and nothing tints while down", function()
    local NS, M, state = tintInstance()
    local before = snapshots(M)
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    local down = true
    NS.IsStoodDown = function() return down end
    NS.QuickSlots.Suspend()
    -- red under: a Suspend that leaves the tint (QS.Suspend's DrawerSync without the tint sync).
    for i, t in ipairs(rim(M)) do sameAs(t, before[i], "rim texture " .. i .. " after the stand-down") end
    M.EquipmentFlyout_UpdateItems()
    NS.QuickSlots.DrawerSync()
    for i, t in ipairs(rim(M)) do sameAs(t, before[i], "rim texture " .. i .. " while down") end
end)

test("flyout tint: nothing is written in combat lockdown", function()
    local NS, M, state = tintInstance()
    M.InCombatLockdown = function() return true end
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    -- red under: a tint path without the lockdown check.
    for i, t in ipairs(rim(M)) do assertEqual(t.writes, 0, "rim texture " .. i .. " was written in lockdown") end
    M.InCombatLockdown = function() return false end
    M.EquipmentFlyout_UpdateItems()
    for i, t in ipairs(rim(M)) do tintedWith(t, border(NS), "rim texture " .. i .. " after lockdown") end
end)

test("flyout tint: a tinted rim is not written over in lockdown either", function()
    local NS, M, state = tintInstance()
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    local writes = {}
    for i, t in ipairs(rim(M)) do writes[i] = t.writes end
    M.InCombatLockdown = function() return true end
    setWindow(NS, state, false)
    -- red under: a restore path without the lockdown check.
    for i, t in ipairs(rim(M)) do assertEqual(t.writes, writes[i], "rim texture " .. i .. " was written in lockdown") end
end)

test("flyout tint: a skin change in lockdown writes nothing", function()
    local NS, M, state = tintInstance()
    local Skin = M.LibStub("LibKa0s-Skin-1.0", true)
    setWindow(NS, state, true)
    openOn(M, M.__slotButtons.HeadSlot)
    local writes = {}
    for i, t in ipairs(rim(M)) do writes[i] = t.writes end
    M.InCombatLockdown = function() return true end
    local key = otherSkin(NS, Skin)
    assertTrue(key ~= nil, "no shipped skin has a different win.border, so the case proves nothing")
    -- red under: QS.TintSync without its own lockdown check (the skin listener reaches it directly).
    for i, t in ipairs(rim(M)) do assertEqual(t.writes, writes[i], "rim texture " .. i .. " was written in lockdown") end
    M.InCombatLockdown = function() return false end
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
end)
