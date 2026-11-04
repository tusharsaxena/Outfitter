local _, NS = ...
-- modules/QuickSlots.lua — NS.QuickSlots: the equipment flyout hooks (design §7.9, INV §3.11).
--
-- Clicking a character-sheet slot with an item on the cursor, or clicking an empty slot, forces the
-- Blizzard flyout open; clicking the slot the flyout is open on closes it. The flyout lists only the
-- items that are not already worn (bag and bank items stay), sorted by upgrade track, then item
-- level, then name (modules/QuickSlots_Sort.lua, which extends this table with QS.Sort).
--
-- HOOKS, NEVER REPLACEMENTS (design §7.0 rule 3, skinning-§7). The slot buttons take HookScript on
-- PreClick and PostClick; the flyout's PaperDollItemsFrame.flyoutSettings.getItemsFunc and
-- postGetItemsFunc take hooksecurefunc post-hooks, which filter and sort the tables the original
-- filled, in place. The legacy code replaced both functions (OutfitterQuickSlots.lua:17-36). A
-- post-hook receives the caller's numItems, not the original's return: the original inserts "place in
-- bags" at index 1 and answers numItems + 1, so the count is read from the dense display table.
--
-- BUILT ONCE, ON THE FIRST STAND-UP (Resume, which the login's OnEnable runs; design §5.12). The hooks
-- cannot be removed, so a stand-down leaves them installed and every body reads the gate first: the
-- latch, then the profile's `quickSlots.enabled` (H26). QuickSlots owns no frames, events or timers.
--
-- THE DRAWER (sheet and window feedback design G8, smoke round 2 design G3; owner ruling: only while
-- the outfit window shows). Every slot's arrow is shown, the left column's arrows and flyouts open
-- left, away from the sheet, the way the right column's open right, and a character-sheet slot's flyout
-- lines up with its slot. Verified at wow-ui-source@297d7aa (`live`):
--   * the arrow template is hidden (Blizzard_FrameXML/EquipmentFlyout.xml:26-37), and only the
--     Equipment Manager pane shows the arrows: its OnShow calls EquipmentFlyoutPopoutButton_ShowAll and
--     its OnHide _HideAll (Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:2316-2319, 2345-2346;
--     the pane is PaperDollFrame.EquipmentManagerPane, :134). HideAll also unlocks every popout and
--     hides a locked flyout (EquipmentFlyout.lua:598-612). So DrawerSync shows every slot's own
--     `button.popoutButton`, weapons included, per button (never ShowAll/HideAll, which write
--     flyoutLocked from this context), and hides them again when the window goes, unless the pane is
--     shown (its arrows are Blizzard's). A locked flyout is closed through EquipmentFlyout_Hide first,
--     whose OnHide clears the lock and the reversal (:98-107), so no flyout outlives its arrow. A
--     HideAll post-hook shows them again while still wanted (leaving the Equipment Manager tab with the
--     window open); it never reopens a flyout. Alpha is never touched, so EllesmereUI's "hide slot
--     flyout arrows" setting keeps working;
--   * the arrow is anchored once, in PaperDollItemSlotButton_OnLoad, `LEFT` -> slot `RIGHT` (-8, 0), with
--     the unreversed coords (PaperDollFrame.lua:1515-1534); nothing re-anchors it, so DrawerSync moves
--     the left column's to `RIGHT` -> slot `LEFT` (+8, 0), mirrored, when the window shows, and puts
--     Blizzard's exact anchor and coords back when it hides or the addon stands down;
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
-- Blizzard's flyoutSettings table is never written; the weapons' (vertical) flyouts and the other
-- hosts' (Item Upgrade, Item Interaction, Runeforge) keep Blizzard's anchor; and nothing is written
-- in combat lockdown: the window hides at PLAYER_REGEN_DISABLED, before lockdown, and its hide
-- restores the drawer (modules/Dock.lua). None of these frames is protected. The drawer's gate is the
-- stand-down latch and the window, not `quickSlots.enabled`, which is the flyout's lists and clicks
-- only. Each global hook is installed only when the client has the function.
--
-- CLIENT READS beyond this file's luacheck stanza go through `_G` by name, read at call time:
-- CursorHasItem, EquipmentFlyoutFrame, EquipmentFlyout_UpdateItems,
-- EquipmentFlyoutPopoutButton_SetReversed, EquipmentFlyoutPopoutButton_HideAll, PaperDollFrame, and the
-- ITEM_INVENTORY_LOCATION_*, EQUIPMENTFLYOUT_BORDERWIDTH and EFITEM_HEIGHT numbers (each with the
-- client's value as its fallback). Every link is read through NS.Compat, which hands a secret one back
-- as nil.
--
-- CALLS (at call time; design §12): NS.Dock.IsVisible, NS.SlotEnables.COLUMN.

local QS = {}
NS.QuickSlots = QS

local Compat, Secrets = NS.Compat, NS.Secrets

-- The client's packed-location bits (ITEM_INVENTORY_LOCATION_*): the fallbacks when it has none.
local PLAYER_BIT, BAGS_BIT, BANK_BIT = 0x00100000, 0x00200000, 0x00400000

local installed = false
local currentSlot           -- the slot name of the last PreClick (the legacy CurrentInventorySlot)
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

local function preClick(button)
    if not active() then return end
    currentSlot = slotOf[button]
end

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

local drawerOn = false            -- the arrows are shown and the left column's sit on the slot's left
local flyoutMoved = false         -- buttonFrame carries this file's point, not Blizzard's

local function locked() return Compat.InCombatLockdown() end

-- The drawer opens outward: standing up and the outfit window on screen. Visible, not shown: a
-- window parked in the sheet holder keeps its shown flag when the sheet hides it.
local function drawerWanted()
    return not NS.IsStoodDown() and NS.Dock.IsVisible() == true
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

-- One left-column arrow out (on the slot's left, mirrored) or back to Blizzard's anchor and coords.
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

-- The flyout's item frame: beside a character-sheet slot's horizontal flyout while wanted, else
-- Blizzard's own point, written back only when this file moved it.
local function placeFlyout()
    local flyout = _G.EquipmentFlyoutFrame
    local frame = flyout and flyout.buttonFrame
    if not frame then return end
    local button = flyout.button
    local want = button ~= nil and slotOf[button] ~= nil and not button.verticalFlyout and drawerWanted()
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

-- EquipmentFlyout_UpdateItems' post-hook.
local function onFlyoutUpdate()
    if locked() then return end
    placeFlyout()
end

-- EquipmentFlyoutPopoutButton_SetReversed's post-hook: a moved arrow keeps pointing outward.
local function onSetReversed(popout, reversed)
    if not drawerOn or locked() or type(popout) ~= "table" or not popout.GetParent then return end
    if leftColumn(popout:GetParent()) then paintArrow(popout, reversed == true, true) end
end

-- EquipmentFlyoutPopoutButton_HideAll's post-hook: the arrows back while still wanted. Shows only; the
-- flyout HideAll closed stays closed.
local function onHideAll()
    if drawerOn and drawerWanted() and not locked() then showArrows(true) end
end

--- Bring the drawer in line with the window: every arrow shown and the left column's out while the
--- window shows, Blizzard's back otherwise, and an open flyout with them (placed before the arrows
--- hide, so a locked flyout closed with its arrow keeps Blizzard's point). Dock's window OnShow /
--- OnHide call it; so does the stand-down. Never in combat lockdown.
function QS.DrawerSync()
    if not installed or locked() then return end
    local want = drawerWanted()
    if want == drawerOn then return placeFlyout() end
    for button, slot in pairs(slotOf) do
        if NS.SlotEnables.COLUMN[slot] == "LEFT" then placeArrow(button, want) end
    end
    drawerOn = want
    placeFlyout()
    showArrows(want)
end

-- Post-hook the client global `name` with `fn` when the client has it (hooksecurefunc raises on a
-- missing one).
local function hookGlobal(name, fn)
    if type(_G[name]) ~= "function" then return end
    hooksecurefunc(name, fn)
end

-- ── the lifecycle ─────────────────────────────────────────────────────────────────────────────

--- Build the hooks: once per session, however often the addon stands up.
function QS.Install()
    if installed then return end
    installed = true
    for _, slotName in ipairs(NS.ItemData.SLOT_NAMES) do
        local button = _G["Character" .. slotName]
        if button then
            slotOf[button] = slotName
            button:HookScript("PreClick", preClick)
            button:HookScript("PostClick", postClick)
        end
    end
    if type(hooksecurefunc) ~= "function" then return end
    hookGlobal("EquipmentFlyout_UpdateItems", onFlyoutUpdate)
    hookGlobal("EquipmentFlyoutPopoutButton_SetReversed", onSetReversed)
    hookGlobal("EquipmentFlyoutPopoutButton_HideAll", onHideAll)
    local settings = PaperDollItemsFrame and PaperDollItemsFrame.flyoutSettings
    if type(settings) ~= "table" then return end
    hookFlyout(settings, "getItemsFunc", filterItems)
    hookFlyout(settings, "postGetItemsFunc", sortItems)
end

--- The lifecycle's stand-down (design §5.12): the hooks stay installed and their bodies read the
--- latch; the clicked slot is forgotten and the drawer goes back to Blizzard's.
function QS.Suspend()
    currentSlot = nil
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

--- The slot name of the last slot button pressed, or nil.
--- @return string|nil
function QS.CurrentSlot() return currentSlot end
