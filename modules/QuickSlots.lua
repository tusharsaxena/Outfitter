local _, NS = ...
-- modules/QuickSlots.lua — NS.QuickSlots: the equipment flyout hooks (design §7.9, INV §3.11).
--
-- Clicking a character-sheet slot with an item on the cursor, or clicking an empty slot, forces the
-- Blizzard flyout open; clicking the slot the flyout is open on closes it. The flyout lists only the
-- items that are not already worn (bag and bank items stay), sorted by upgrade track, then item
-- level, then name (modules/QuickSlots_Sort.lua, which extends this table with QS.Sort).
--
-- HOOKS, NEVER REPLACEMENTS (design §7.0 rule 3, skinning-§7). The slot buttons take HookScript on
-- PostClick; the flyout's PaperDollItemsFrame.flyoutSettings.getItemsFunc and
-- postGetItemsFunc take hooksecurefunc post-hooks, which filter and sort the tables the original
-- filled, in place. The legacy code replaced both functions (OutfitterQuickSlots.lua:17-36). A
-- post-hook receives the caller's numItems, not the original's return: the original inserts "place in
-- bags" at index 1 and answers numItems + 1, so the count is read from the dense display table.
--
-- BUILT ONCE, ON THE FIRST STAND-UP (Resume, which the login's OnEnable runs; design §5.12). The hooks
-- cannot be removed, so a stand-down leaves them installed and every body reads the gate first: the
-- latch, then the profile's `quickSlots.enabled` (H26). QuickSlots owns no frames, events or timers.
--
-- THE DRAWER (sheet and window feedback design G8, smoke round 2 design G3; Forever smoke feedback S7,
-- owner 2026-11-09: no longer only while the outfit window shows). While the paper doll is on screen
-- and `window.drawer` is on, every slot's arrow is shown and every flyout opens away from the doll: the
-- left column left, the right column right, the bottom row down. Retail, verified at
-- wow-ui-source@297d7aa (`live`):
--   * the arrow template is hidden (Blizzard_FrameXML/EquipmentFlyout.xml:26-37), and only the
--     Equipment Manager pane shows the arrows: its OnShow calls EquipmentFlyoutPopoutButton_ShowAll and
--     its OnHide _HideAll (Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:2316-2319, 2345-2346;
--     the pane is PaperDollFrame.EquipmentManagerPane, :134). HideAll also unlocks every popout and
--     hides a locked flyout (EquipmentFlyout.lua:598-612). So DrawerSync shows every slot's own
--     `button.popoutButton`, weapons included, per button (never ShowAll/HideAll, which write
--     flyoutLocked from this context), and hides them again when the doll goes, unless the pane is
--     shown (its arrows are Blizzard's). A locked flyout is closed through EquipmentFlyout_Hide first,
--     whose OnHide clears the lock and the reversal (:98-107), so no flyout outlives its arrow. A
--     HideAll post-hook shows them again while still wanted (leaving the Equipment Manager tab); it
--     never reopens a flyout. Alpha is never touched, so EllesmereUI's "hide slot flyout arrows"
--     setting keeps working;
--   * the arrow is anchored once, in PaperDollItemSlotButton_OnLoad, `LEFT` -> slot `RIGHT` (-8, 0), with
--     the unreversed coords (PaperDollFrame.lua:1515-1534); nothing re-anchors it, so DrawerSync moves
--     the left column's to `RIGHT` -> slot `LEFT` (+8, 0), mirrored, while wanted, and puts
--     Blizzard's exact anchor and coords back when the doll hides or the addon stands down. The right
--     column and the (vertical) weapons already open outward;
--   * EquipmentFlyoutPopoutButton_SetReversed sets the arrow's coords on every open and close
--     (Blizzard_FrameXML/EquipmentFlyout.lua:633-651); its post-hook mirrors a left-column arrow's;
--   * EquipmentFlyout_UpdateItems places the items, anchoring `flyout.buttonFrame` `TOPLEFT` -> the arrow's
--     `TOPRIGHT` + (anchorX, anchorY) without clearing it first (EquipmentFlyout.lua:331-339;
--     PaperDollItemsFrame.flyoutSettings, PaperDollFrame.lua:343-354). The items sit BORDERWIDTH (3)
--     inside it and are EFITEM_HEIGHT (37) tall (:39, 44, 67), so Blizzard's first item starts 5.5 px
--     below a 37 px slot's top. The post-hook re-anchors a character-sheet slot's horizontal flyout to
--     the SLOT, past the arrow's visible 8 px: right column `TOPLEFT` -> slot `TOPRIGHT` (8, y), left
--     column `TOPRIGHT` -> slot `TOPLEFT` (-8, y), y = BORDERWIDTH - (slot height - EFITEM_HEIGHT) / 2,
--     so the first item is level with the slot. The flyout's background textures hang off buttonFrame
--     (:345-400), so they follow. A moved buttonFrame is cleared and given Blizzard's own point back
--     the next time it is not wanted, so Blizzard's TOPLEFT never joins ours.
-- WoW Forever reaches the same drawer through its own flyout code: see "WoW Forever's drawer" below.
-- Blizzard's flyoutSettings table is never written; the weapons' (vertical) flyouts and the other
-- hosts' (Item Upgrade, Item Interaction, Runeforge) keep Blizzard's anchor; and nothing is written
-- in combat lockdown: a doll shown or hidden in lockdown leaves the drawer as it was, and Dock's
-- PLAYER_REGEN_ENABLED syncs it. None of these frames is protected. The drawer's gate is the
-- stand-down latch, the paper doll and the Outfit Window page's `window.drawer` (smoke round 3 E11;
-- Dock's receiver syncs a write or a profile switch), not `quickSlots.enabled`, which is the flyout's
-- lists and clicks only. Each global hook is installed only when the client has the function.
--
-- CLIENT READS beyond this file's luacheck stanza go through `_G` by name, read at call time:
-- CursorHasItem, EquipmentFlyoutFrame, EquipmentFlyout_UpdateItems,
-- EquipmentFlyoutPopoutButton_SetReversed, EquipmentFlyoutPopoutButton_HideAll,
-- EquipmentFlyoutPopoutButton_RefreshVisualState, PaperDollFrame, and the
-- ITEM_INVENTORY_LOCATION_*, EQUIPMENTFLYOUT_BORDERWIDTH and EFITEM_HEIGHT numbers (each with the
-- client's value as its fallback). Every link is read through NS.Compat, which hands a secret one back
-- as nil.
--
-- THE BORDER TINT (smoke round 3 E1): the one Blizzard frame this addon colors, under the accepted
-- deviation DEV-SKIN-FLYOUT-TINT; see "the flyout's border tint" below.
--
-- CALLS (at call time; design §12): NS.Dock.IsVisible (the tint), NS.Dock.DollVisible (the drawer),
-- NS.SlotEnables.COLUMN, NS.Skin.Color and
-- NS.Skin.OnLooksChanged (the tint).

local QS = {}
NS.QuickSlots = QS

local Compat, Secrets = NS.Compat, NS.Secrets

-- The client's packed-location bits (ITEM_INVENTORY_LOCATION_*): the fallbacks when it has none.
local PLAYER_BIT, BAGS_BIT, BANK_BIT = 0x00100000, 0x00200000, 0x00400000

local installed = false
local slotOf = {}           -- slot button -> its slot name

-- A FrameXML number by name, plain, or `fallback` when the client has none.
local function clientNumber(name, fallback)
    return Secrets.UnsecretNumber(_G[name], fallback)
end

--- THE gate every hook body reads first: standing up, and quick slots on in this profile.
--- @return boolean
local function active()
    if NS.IsStoodDown() then return false end
    return NS.GetSetting("quickSlots.enabled") ~= false
end

-- ── the flyout's lists ────────────────────────────────────────────────────────────────────────

-- Whether a packed flyout location is on the player itself (worn), not in the bags or the bank.
local function onPlayer(location)
    local player = clientNumber("ITEM_INVENTORY_LOCATION_PLAYER", PLAYER_BIT)
    local mask = player + clientNumber("ITEM_INVENTORY_LOCATION_BAGS", BAGS_BIT)
        + clientNumber("ITEM_INVENTORY_LOCATION_BANK", BANK_BIT)
    return Compat.BitAnd(location, mask) == player
end

-- getItemsFunc's post-hook: remove items on the player from the choices.
local function filterItems(_, itemTable)
    if not active() or type(itemTable) ~= "table" then return end
    for location in pairs(itemTable) do
        if onPlayer(location) then itemTable[location] = nil end
    end
end

-- postGetItemsFunc's post-hook: order the choices by upgrade track, then item level, then name, and
-- move "place in bags" from the front to the end.
local function sortItems(_, displayTable)
    if not active() or type(displayTable) ~= "table" then return end
    local n = #displayTable
    QS.Sort.Items(displayTable, n)
    QS.Sort.PlaceInBagsLast(displayTable, n)
end

-- ── the slot buttons ──────────────────────────────────────────────────────────────────────────

-- Whether the flyout is showing for `button`.
local function flyoutOpenOn(button)
    local flyout = _G.EquipmentFlyoutFrame
    if not flyout then return false end
    return flyout:IsVisible() and flyout.button == button
end

-- The popout's own click handler toggles on its flyoutLocked: locked, it unlocks, hides the flyout
-- and turns the arrow back; unlocked, it locks, shows the flyout and reverses the arrow. Every open
-- and every close of a locked flyout goes through it, so Blizzard keeps its own state and this file
-- writes none of it. A bare EquipmentFlyout_Hide leaves the lock set, and the next click on the slot
-- would then only unlock it.
local function postClick(button)
    if not active() then return end
    local popout = button.popoutButton
    if flyoutOpenOn(button) then
        if popout and popout.flyoutLocked then
            EquipmentFlyoutPopoutButton_OnClick(popout)
        else
            EquipmentFlyout_Hide()
        end
        return
    end
    -- If there's an item on the cursor after clicking or the slot is empty then open the flyout.
    local cursorHasItem = _G.CursorHasItem
    local cursorItem = type(cursorHasItem) == "function" and Secrets.PlainTruth(cursorHasItem()) == true
    local empty = not Compat.InventoryItemLink(button.id or button:GetID())
    if not popout or not (cursorItem or empty) then return end
    -- A lock left set by a flyout closed some other way would make this click its unlock: clear it
    -- through the handler first, so the open always opens (the legacy PostClick forced it open).
    if popout.flyoutLocked then EquipmentFlyoutPopoutButton_OnClick(popout) end
    EquipmentFlyoutPopoutButton_OnClick(popout)
end

-- Post-hook `settings[name]` with `fn` when the client has that function (hooksecurefunc raises on a
-- missing member).
local function hookFlyout(settings, name, fn)
    if type(settings[name]) ~= "function" then return end
    hooksecurefunc(settings, name, fn)
end

-- ── the outward drawer ──────────────────────────────────────────────────────────────────────────

-- Blizzard's horizontal arrow coords, unreversed and reversed, in SetTexCoord's eight-value corner
-- order (EquipmentFlyout.lua:643-649; the unreversed pair is also PaperDollFrame.lua:1527-1528).
local ARROW = {
    [false] = { normal = { 0.15625, 0.5, 0.84375, 0.5, 0.15625, 0, 0.84375, 0 },
                highlight = { 0.15625, 1, 0.84375, 1, 0.15625, 0.5, 0.84375, 0.5 } },
    [true] = { normal = { 0.15625, 0, 0.84375, 0, 0.15625, 0.5, 0.84375, 0.5 },
               highlight = { 0.15625, 0.5, 0.84375, 0.5, 0.15625, 1, 0.84375, 1 } },
}
local ARROW_INSET = 8             -- PaperDollFrame.lua:1532, the arrow's overlap of its slot
local ARROW_WIDTH = 16            -- PaperDollFrame.lua:1530, a horizontal arrow's width
local FLYOUT_GAP = ARROW_WIDTH - ARROW_INSET  -- the arrow's visible half, between slot and items
local SLOT_HEIGHT = 37            -- a stock slot button, when the client answers no height

-- WoW Forever's drawer (ruling D4; Forever smoke feedback S7 makes it outward). F-UI (Forever 1.60.1,
-- wow-ui-source@9dc84f0) gives each slot a `flyoutDirection` (the left column RIGHT, the right column
-- LEFT, the bottom row UP: inward; Camelot/PaperDollFrame.xml:136-165), anchors the arrow by it 5 px off
-- the slot (Camelot/PaperDollFrame.lua:1976-1989), draws it as a rotated atlas sized by it
-- (EquipmentFlyoutPopoutButton_RefreshVisualState, Camelot/EquipmentFlyout.lua:707-755) and anchors
-- `buttonFrame` by it on every EquipmentFlyout_UpdateItems after a ClearAllPoints (:420-433). The drawer
-- never writes `flyoutDirection`: it anchors the arrow by F-UI's own rule for the OUTWARD direction
-- (OUT_DIR, SLOT_DIR), repaints it from a RefreshVisualState post-hook (the art, size and turn F-UI
-- gives that direction: paintForeverArrow), and re-anchors buttonFrame by F-UI's own formula for
-- that direction from the UpdateItems post-hook. The flyout's backgrounds hang inside buttonFrame
-- whatever the direction (:435-530), so they follow. Put back: the arrow at Blizzard's own anchor and
-- RefreshVisualState run again; the next UpdateItems anchors buttonFrame Blizzard's way.
-- S3: F-UI's 5 px gap sits under the slot's BorderFrame art; with BorderFrame hidden (Chonky
-- Character Sheet hides it, CCS-F Modules/Forever.lua:1340) the outward arrow sits flush on the slot.
local FOREVER_DRAWER = NS.PerClient({ retail = false, forever = true })
local OUT_DIR = { LEFT = "LEFT", RIGHT = "RIGHT", BOTTOM = "DOWN" }
-- The bottom row by slot (Forever smoke feedback 3, owner 2026-11-09, 26.png): the main hand and the
-- ranged slot open left, the off-hand and the ammo slot right. Chonky stacks them two by two, the
-- main hand over the ranged slot on the left; the stock sheet keeps them in a row.
local SLOT_DIR = { MainHandSlot = "LEFT", RangedSlot = "LEFT", SecondaryHandSlot = "RIGHT", AmmoSlot = "RIGHT" }
-- POP_OUT_DIRECTION_DATA's art and sizes (Camelot/EquipmentFlyout.lua:691-718): the sides share the
-- PullSide atlases at 20 x 43, up and down the PullUp ones at 43 x 20. A slot turned from up to a side
-- takes the side's art and size, not only its rotation.
local SIDE_ART = { normal = "UI-Character-Info-Button-PullSide", open = "UI-Character-Info-Button-PullSide-Open",
                   pressed = "UI-Character-Info-Button-PullSide-Pressed", w = 20, h = 43 }
local UP_ART = { normal = "UI-Character-Info-Button-PullUp", open = "UI-Character-Info-Button-PullUp-Open",
                 pressed = "UI-Character-Info-Button-PullUp-Pressed", w = 43, h = 20 }
local ART = { LEFT = SIDE_ART, RIGHT = SIDE_ART, UP = UP_ART, DOWN = UP_ART }
-- The ammo slot (Forever smoke feedback 3): F-UI gives CharacterAmmoSlot no arrow
-- (Camelot/PaperDollFrame.xml:873-927), so the drawer makes one from Blizzard's own
-- EquipmentFlyoutPopoutButtonTemplate. Its click runs Blizzard's EquipmentFlyout_Show on the slot,
-- which lists ammo through PaperDollItemsFrame's flyoutSettings like any slot. The arrow is the
-- slot's `popoutButton` so Blizzard's lock and close logic finds it. Ammo is not part of an outfit
-- yet (tusharsaxena/OutfitterReborn#1): this is the flyout only.
local AMMO_TEMPLATE = "EquipmentFlyoutPopoutButtonTemplate"
local POP_OUT_GAP = 5             -- Camelot/PaperDollFrame.lua:1981-1987
-- POP_OUT_DIRECTION_DATA's rotations (Camelot/EquipmentFlyout.lua:713-718): the baseline pi/2 added.
local ROTATION = { LEFT = 0, RIGHT = math.pi, UP = 0, DOWN = math.pi }

local drawerOn = false            -- the arrows are shown and turned outward
local flyoutMoved = false         -- buttonFrame carries this file's point, not Blizzard's (Retail)

local function locked() return Compat.InCombatLockdown() end

-- The drawer opens outward (Forever smoke feedback S7, superseding sheet and window feedback design
-- G8's "only while the window shows"): standing up, the Outfit Window page's `window.drawer` on and the
-- paper doll on screen, whether or not the outfit window is.
local function drawerWanted()
    if NS.IsStoodDown() or NS.GetSetting("window.drawer") == false then return false end
    return NS.Dock.DollVisible() == true
end

local function leftColumn(button)
    local slot = button and slotOf[button]
    return slot ~= nil and NS.SlotEnables.COLUMN[slot] == "LEFT"
end

-- A texture's coords, mirrored left to right: the upper and lower right corners trade with the left.
local function setCoords(texture, c, mirrored)
    if not texture then return end
    if mirrored then
        texture:SetTexCoord(c[5], c[6], c[7], c[8], c[1], c[2], c[3], c[4])
    else
        texture:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
    end
end

local function paintArrow(popout, reversed, mirrored)
    local c = ARROW[reversed == true]
    setCoords(popout.GetNormalTexture and popout:GetNormalTexture(), c.normal, mirrored)
    setCoords(popout.GetHighlightTexture and popout:GetHighlightTexture(), c.highlight, mirrored)
end

-- Retail: one left-column arrow out (on the slot's left, mirrored) or back to Blizzard's anchor and
-- coords.
local function placeArrow(button, out)
    local popout = button.popoutButton
    if not popout or button.verticalFlyout then return end
    popout:ClearAllPoints()
    if out then
        popout:SetPoint("RIGHT", button, "LEFT", ARROW_INSET, 0)
    else
        popout:SetPoint("LEFT", button, "RIGHT", -ARROW_INSET, 0)
    end
    paintArrow(popout, popout.flyoutLocked == true, out)
end

-- Forever: the slot's outward direction, or nil for a slot outside the three columns.
local function outDir(button)
    local slot = button and slotOf[button]
    if not slot then return nil end
    return SLOT_DIR[slot] or OUT_DIR[NS.SlotEnables.COLUMN[slot]]
end

-- Whether the slot's BorderFrame art (which covers F-UI's 5 px arrow gap) is drawn.
local function borderShown(button)
    local border = rawget(button, "BorderFrame")
    if type(border) ~= "table" or type(border.IsShown) ~= "function" then return true end
    return Secrets.PlainTruth(border:IsShown()) == true
end

-- F-UI's arrow anchor for `dir`, `gap` px off the slot (Camelot/PaperDollFrame.lua:1979-1988).
local function anchorPopout(popout, button, dir, gap)
    popout:ClearAllPoints()
    if dir == "LEFT" then
        popout:SetPoint("RIGHT", button, "LEFT", -gap, 0)
    elseif dir == "UP" then
        popout:SetPoint("BOTTOM", button, "TOP", 0, gap)
    elseif dir == "DOWN" then
        popout:SetPoint("TOP", button, "BOTTOM", 0, -gap)
    else
        popout:SetPoint("LEFT", button, "RIGHT", gap, 0)
    end
end

-- The arrow's three textures turned for `dir`, as RefreshVisualState turns them.
local function rotateArrow(popout, dir)
    local r = ROTATION[dir] or 0
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
        local t = type(popout[getter]) == "function" and popout[getter](popout)
        if t and type(t.SetRotation) == "function" then t:SetRotation(r) end
    end
end

-- The arrow drawn for `dir` as RefreshVisualState draws it: the art set and size for that side, the
-- open art while its flyout is locked, then the turn.
local function paintForeverArrow(popout, dir)
    local art = ART[dir]
    if art and type(popout.SetNormalAtlas) == "function" then
        local normal = popout.flyoutLocked and art.open or art.normal
        popout:SetNormalAtlas(normal, true)
        popout:SetPushedAtlas(art.pressed, true)
        popout:SetHighlightAtlas(normal, "ADD")
    end
    if art and type(popout.SetSize) == "function" then popout:SetSize(art.w, art.h) end
    rotateArrow(popout, dir)
end

-- Forever: one arrow outward (F-UI's anchor for the outward direction, S3's gap, turned) or back to
-- Blizzard's own anchor and look.
local function placeForeverArrow(button, out)
    local popout, dir = button.popoutButton, outDir(button)
    if not popout or not dir then return end
    if out then
        anchorPopout(popout, button, dir, borderShown(button) and POP_OUT_GAP or 0)
        paintForeverArrow(popout, dir)
        return
    end
    anchorPopout(popout, button, button.flyoutDirection, POP_OUT_GAP)
    local refresh = _G.EquipmentFlyoutPopoutButton_RefreshVisualState
    if type(refresh) == "function" then refresh(popout) end
end

-- The button's own host's settings, as Blizzard reads them (EquipmentFlyout.lua:244): the Item
-- Upgrade, Item Interaction and Runeforge frames share this flyout with their own (20, -8).
local function hostSettings(button)
    local host = button.GetParent and button:GetParent()
    if type(host) == "table" and type(host.flyoutSettings) == "table" then return host.flyoutSettings end
    return PaperDollItemsFrame and PaperDollItemsFrame.flyoutSettings or {}
end

-- Blizzard's own point for the cleared item frame (EquipmentFlyout.lua:335-339), by the button's host's
-- settings: below a vertical flyout, else beside the arrow (or the button, with none).
local function blizzardAnchor(frame, button)
    local settings = hostSettings(button)
    local rel = button.popoutButton or button
    if button.verticalFlyout then
        frame:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", NS.SafeNumber(settings.verticalAnchorX, 0),
            NS.SafeNumber(settings.verticalAnchorY, 0))
    else
        frame:SetPoint("TOPLEFT", rel, "TOPRIGHT", NS.SafeNumber(settings.anchorX, 0),
            NS.SafeNumber(settings.anchorY, 0))
    end
end

-- Forever: the item frame by F-UI's own formula for `dir` (Camelot/EquipmentFlyout.lua:424-433).
local function foreverAnchor(frame, button, dir)
    local s = hostSettings(button)
    local rel = button.popoutButton or button
    local ax, ay = NS.SafeNumber(s.anchorX, 0), NS.SafeNumber(s.anchorY, 0)
    local vx, vy = NS.SafeNumber(s.verticalAnchorX, 0), NS.SafeNumber(s.verticalAnchorY, 0)
    frame:ClearAllPoints()
    if dir == "LEFT" then
        frame:SetPoint("TOPRIGHT", rel, "TOPLEFT", -ax, ay)
    elseif dir == "UP" then
        frame:SetPoint("BOTTOMLEFT", rel, "TOPLEFT", vx, -vy)
    elseif dir == "DOWN" then
        frame:SetPoint("TOPLEFT", rel, "BOTTOMLEFT", vx, vy)
    else
        frame:SetPoint("TOPLEFT", rel, "TOPRIGHT", ax, ay)
    end
end

-- A slot button's height, plain; a stock slot's when the client answers none.
local function slotHeight(button)
    local ok, h = pcall(button.GetHeight, button)
    h = ok and NS.SafeNumber(h, 0) or 0
    return h > 0 and h or SLOT_HEIGHT
end

-- The cleared item frame beside the slot itself, past the arrow, its first item level with the slot:
-- outward (to the slot's left) for the left column.
local function alignFlyout(frame, button)
    local y = clientNumber("EQUIPMENTFLYOUT_BORDERWIDTH", 3)
        - (slotHeight(button) - clientNumber("EFITEM_HEIGHT", SLOT_HEIGHT)) / 2
    if leftColumn(button) then
        frame:SetPoint("TOPRIGHT", button, "TOPLEFT", -FLYOUT_GAP, y)
    else
        frame:SetPoint("TOPLEFT", button, "TOPRIGHT", FLYOUT_GAP, y)
    end
end

-- Forever's item frame: outward by F-UI's formula while wanted, else Blizzard's for its own direction
-- (only when the drawer last moved it: Blizzard re-anchors it on its own every UpdateItems).
local function placeForeverFlyout(frame, button, want)
    local dir = outDir(button)
    if want and dir then
        foreverAnchor(frame, button, dir)
        flyoutMoved = true
    elseif flyoutMoved then
        foreverAnchor(frame, button, button.flyoutDirection)
        flyoutMoved = false
    end
end

-- The flyout's item frame: beside a character-sheet slot's horizontal flyout while wanted, else
-- Blizzard's own point, written back only when this file moved it.
local function placeFlyout()
    local flyout = _G.EquipmentFlyoutFrame
    local frame = flyout and flyout.buttonFrame
    if not frame then return end
    local button = flyout.button
    local onSheet = button ~= nil and slotOf[button] ~= nil
    if FOREVER_DRAWER then
        if onSheet then placeForeverFlyout(frame, button, drawerWanted()) end
        return
    end
    local want = onSheet and not button.verticalFlyout and drawerWanted()
    if not want and not flyoutMoved then return end
    frame:ClearAllPoints()
    flyoutMoved = false
    if not button then return end
    if want then
        alignFlyout(frame, button)
        flyoutMoved = true
    else
        blizzardAnchor(frame, button)
    end
end

-- Whether the Equipment Manager pane is shown: its arrows are Blizzard's, never hidden from here.
local function equipmentPaneShown()
    local doll = _G.PaperDollFrame
    local pane = type(doll) == "table" and doll.EquipmentManagerPane
    if type(pane) ~= "table" or type(pane.IsShown) ~= "function" then return false end
    return Secrets.PlainTruth(pane:IsShown()) == true
end
-- Every slot's own arrow shown, or hidden with a locked flyout on it closed first (its OnHide clears
-- the lock). Per button, never ShowAll/HideAll. Hides nothing while the Equipment Manager pane shows.
local function showArrows(want)
    if not want and equipmentPaneShown() then return end
    for button in pairs(slotOf) do
        local popout = button.popoutButton
        if popout and want then
            popout:Show()
        elseif popout then
            if popout.flyoutLocked and type(EquipmentFlyout_Hide) == "function" then EquipmentFlyout_Hide() end
            popout:Hide()
        end
    end
end

-- ── the flyout's border tint (smoke round 3 E1; deviation DEV-SKIN-FLYOUT-TINT) ──────────────────
--
-- The one place this addon colors a Blizzard frame: the accepted deviation DEV-SKIN-FLYOUT-TINT
-- (skinning-§7, docs/ARCHITECTURE.md -> Documented deviations; owner ruling 2026-11-05). While the
-- window is on screen and the flyout is open on one of the 18 sheet slots (this file's slotOf), its
-- rim takes the skin's `win.border`: vertex color, desaturated so the hue is the token's. Tint only:
-- no new art, no reparenting, nothing moved (the drawer above anchors). The rim, at
-- wow-ui-source@297d7aa (Blizzard_FrameXML), is the UI-GearManager-Flyout art: `buttonFrame.bg1` (EquipmentFlyout.xml:61-69) and the bg2..bgN
-- that _createFlyoutBG adds as a page needs them (EquipmentFlyout.lua:121-135, laid out at :345-431),
-- plus `NavigationFrame.BottomBackground` (xml:83-86), the paging strip of the same art. The flyout's
-- `Highlight` (xml:41-51) is the open slot's glow, not the rim, and is left alone.
-- Each texture's color and desaturation are read before its first tint and written back exactly, then
-- forgotten, when the window goes, another host's slot owns the flyout (Item Upgrade, Item
-- Interaction, Runeforge; seen on its EquipmentFlyout_UpdateItems, which runs before the flyout
-- shows, :226-228), and at the stand-down (QS.Suspend). A skin change re-tints (NS.Skin
-- .OnLooksChanged). Nothing is written in combat lockdown; the window hides before it, so the tint is
-- already gone by then. None of these textures is protected. A piece Blizzard makes while tinted is
-- read on its own first tint, so a page change cannot record a tinted color as Blizzard's.

local RIM_TOKEN = "win.border"
local tinted = {}             -- rim texture -> { r, g, b, a, desaturated } as Blizzard had it

-- The flyout's rim textures as it has them now: the background pieces, then the paging strip.
local function rimTextures(flyout)
    local out = {}
    local frame = flyout.buttonFrame
    if type(frame) == "table" then
        for i = 1, NS.SafeNumber(frame.numBGs, 0) do
            local t = frame["bg" .. i]
            if type(t) == "table" then out[#out + 1] = t end
        end
    end
    local nav = flyout.NavigationFrame
    if type(nav) == "table" and type(nav.BottomBackground) == "table" then out[#out + 1] = nav.BottomBackground end
    return out
end

-- This addon holds the flyout: standing up, the window on screen, and a sheet slot's flyout.
local function tintWanted(flyout)
    if NS.IsStoodDown() or NS.Dock.IsVisible() ~= true then return false end
    local button = flyout.button
    return button ~= nil and slotOf[button] ~= nil
end

local function isDesaturated(t)
    return type(t.IsDesaturated) == "function" and Secrets.PlainTruth(t:IsDesaturated()) == true
end

-- Every tinted texture back to what it had, and forgotten.
local function restoreRim()
    for t, was in pairs(tinted) do
        t:SetDesaturated(was[5])
        t:SetVertexColor(was[1], was[2], was[3], was[4])
        tinted[t] = nil
    end
end

-- Every rim texture in the skin's border color, each read first if it has not been.
local function tintRim(flyout)
    local r, g, b, a = NS.Skin.Color(RIM_TOKEN)
    if r == nil then return restoreRim() end
    for _, t in ipairs(rimTextures(flyout)) do
        if not tinted[t] then
            local tr, tg, tb, ta = t:GetVertexColor()
            tinted[t] = { tr, tg, tb, ta, isDesaturated(t) }
        end
        t:SetDesaturated(true)
        t:SetVertexColor(r, g, b, a or 1)
    end
end

--- Bring the flyout's rim in line with who holds it: the skin's border color while this addon does,
--- Blizzard's own otherwise. The flyout's updates, DrawerSync (the window's show and hide, the
--- stand-down) and a skin change call it. Never in combat lockdown.
function QS.TintSync()
    if not installed or locked() then return end
    local flyout = _G.EquipmentFlyoutFrame
    if type(flyout) == "table" and tintWanted(flyout) then return tintRim(flyout) end
    restoreRim()
end

-- THE AMMO HIGHLIGHT (Forever smoke feedback 5, owner 2026-11-09, 32.png). EquipmentFlyout_Show sizes
-- the open slot's glow (`EquipmentFlyoutFrame.Highlight`) to 50 x 50 and puts it at the flyout's LEFT
-- -4 (Camelot/EquipmentFlyout.lua:259-262, EquipmentFlyout.xml:58-66): art made for a 40 px slot. The
-- ammo slot is 27 px (Camelot/PaperDollFrame.xml:874) and a sheet addon may resize it (Chonky), so on
-- it the glow sits too large and off center. On the ammo slot the glow takes the slot's size by the
-- art's own 50 : 40 and centers on it; on any other slot Blizzard's point comes back (Show adds its
-- LEFT point without clearing, so the CENTER one must go).
local GLOW_RATIO = 50 / 40
local glowMoved = false

local function glowScale(f)
    local s = NS.SafeNumber(f:GetEffectiveScale(), 1)
    return s > 0 and s or 1
end

local function fitGlow()
    local flyout = _G.EquipmentFlyoutFrame
    local glow = flyout and rawget(flyout, "Highlight")
    local button = flyout and flyout.button
    if type(glow) ~= "table" or not button then return end
    if slotOf[button] == "AmmoSlot" then
        local k = glowScale(button) / glowScale(flyout)
        local w = NS.SafeNumber(button:GetWidth(), 0) * k
        local h = NS.SafeNumber(button:GetHeight(), 0) * k
        if w <= 0 or h <= 0 then return end
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", button, "CENTER", 0, 0)
        glow:SetSize(w * GLOW_RATIO, h * GLOW_RATIO)
        glowMoved = true
    elseif glowMoved then
        local s = hostSettings(button)
        glow:ClearAllPoints()
        glow:SetPoint("LEFT", flyout, "LEFT", NS.SafeNumber(s.highlightOfsX, -4), NS.SafeNumber(s.highlightOfsY, 0))
        glowMoved = false
    end
end

-- EquipmentFlyout_UpdateItems' post-hook.
local function onFlyoutUpdate()
    if locked() then return end
    placeFlyout()
    fitGlow()
    QS.TintSync()
end

-- EquipmentFlyoutPopoutButton_SetReversed's post-hook (Retail): a moved arrow keeps pointing outward.
local function onSetReversed(popout, reversed)
    if FOREVER_DRAWER or not drawerOn or locked() or type(popout) ~= "table" or not popout.GetParent then return end
    if leftColumn(popout:GetParent()) then paintArrow(popout, reversed == true, true) end
end

-- EquipmentFlyoutPopoutButton_RefreshVisualState's post-hook (Forever): Blizzard turned the arrow for
-- its own direction on a show, an enter or leave, a press or a lock; the drawer turns it outward again.
local function onRefreshVisual(popout)
    if not FOREVER_DRAWER or not drawerOn or locked() or type(popout) ~= "table" or not popout.GetParent then return end
    local dir = outDir(popout:GetParent())
    if dir then paintForeverArrow(popout, dir) end
end

-- EquipmentFlyoutPopoutButton_HideAll's post-hook: the arrows back while still wanted. Shows only; the
-- flyout HideAll closed stays closed.
local function onHideAll()
    if drawerOn and drawerWanted() and not locked() then showArrows(true) end
end

--- Bring the drawer in line with the paper doll: every arrow shown and turned outward while the doll
--- shows (and `window.drawer` is on), Blizzard's back otherwise, and an open flyout with them (placed
--- before the arrows hide, so a locked flyout closed with its arrow keeps Blizzard's point). Dock's doll
--- OnShow / OnHide, its window OnShow / OnHide (the tint), a `window.*` write and the regen call it; so
--- does the stand-down. Never in combat lockdown.
function QS.DrawerSync()
    if not installed or locked() then return end
    QS.TintSync()
    local want = drawerWanted()
    if want == drawerOn then return placeFlyout() end
    drawerOn = want
    for button, slot in pairs(slotOf) do
        if FOREVER_DRAWER then
            placeForeverArrow(button, want)
        elseif NS.SlotEnables.COLUMN[slot] == "LEFT" then
            placeArrow(button, want)
        end
    end
    placeFlyout()
    showArrows(want)
end
--- Place the outward arrows again where they stand (Forever): a sheet addon may hide the slots'
--- BorderFrame art after the doll's OnShow (Chonky sets its sheet up from its own hook), which moves
--- S3's flush rule. Dock's next-frame sheet check calls it. Never in lockdown; a no-op off the drawer.
function QS.DrawerRefresh()
    if not installed or locked() or not drawerOn or not FOREVER_DRAWER then return end
    for button in pairs(slotOf) do placeForeverArrow(button, true) end
end

-- Post-hook the client global `name` with `fn` when the client has it (hooksecurefunc raises on a
-- missing one).
local function hookGlobal(name, fn)
    if type(_G[name]) ~= "function" then return end
    hooksecurefunc(name, fn)
end

-- ── the lifecycle ─────────────────────────────────────────────────────────────────────────────

-- Whether the client has XML template `name`.
local function hasTemplate(name)
    local xml = _G.C_XMLUtil
    return type(xml) == "table" and type(xml.GetTemplateInfo) == "function" and xml.GetTemplateInfo(name) ~= nil
end

-- Forever: the ammo slot's own arrow, made once from Blizzard's template (see AMMO_TEMPLATE).
local function ammoArrow()
    local ammo = _G.CharacterAmmoSlot
    if not FOREVER_DRAWER or type(ammo) ~= "table" then return nil end
    if not rawget(ammo, "popoutButton") and hasTemplate(AMMO_TEMPLATE) then
        local ok, pop = pcall(CreateFrame, "Button", "OutfitterRebornAmmoPopout", ammo, AMMO_TEMPLATE)
        if ok and pop then rawset(ammo, "popoutButton", pop) end
    end
    return ammo
end

--- Build the hooks: once per session, however often the addon stands up.
function QS.Install()
    if installed then return end
    installed = true
    for _, slotName in ipairs(NS.ItemData.SLOT_NAMES) do
        local button = _G["Character" .. slotName]
        if button then
            slotOf[button] = slotName
            button:HookScript("PostClick", postClick)
        end
    end
    local ammo = ammoArrow()
    if ammo then
        slotOf[ammo] = "AmmoSlot"
        ammo:HookScript("PostClick", postClick)
    end
    NS.Skin.OnLooksChanged(QS.TintSync)
    if type(hooksecurefunc) ~= "function" then return end
    hookGlobal("EquipmentFlyout_UpdateItems", onFlyoutUpdate)
    hookGlobal("EquipmentFlyoutPopoutButton_SetReversed", onSetReversed)
    hookGlobal("EquipmentFlyoutPopoutButton_HideAll", onHideAll)
    hookGlobal("EquipmentFlyoutPopoutButton_RefreshVisualState", onRefreshVisual)
    local settings = PaperDollItemsFrame and PaperDollItemsFrame.flyoutSettings
    if type(settings) ~= "table" then return end
    hookFlyout(settings, "getItemsFunc", filterItems)
    hookFlyout(settings, "postGetItemsFunc", sortItems)
end

--- The lifecycle's stand-down (design §5.12): the hooks stay installed and their bodies read the
--- latch; the drawer goes back to Blizzard's.
function QS.Suspend()
    QS.DrawerSync()
end

--- The lifecycle's stand-up: builds the hooks the first time.
function QS.Resume()
    QS.Install()
end

--- The `quickSlots.enabled` row's reaction. The hook bodies read the row themselves, so a profile
--- switch is followed without this call; turning the row on only makes sure the hooks exist.
--- @param enabled boolean
function QS.SetEnabled(enabled)
    if enabled and not NS.IsStoodDown() then QS.Install() end
end
