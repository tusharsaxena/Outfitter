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
-- CLIENT READS beyond this file's luacheck stanza go through `_G` by name, read at call time:
-- CursorHasItem, EquipmentFlyoutFrame and the ITEM_INVENTORY_LOCATION_* bits (each with the client's
-- value as its fallback). Every link is read through NS.Compat, which hands a secret one back as nil.

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

local function postClick(button)
    if not active() then return end
    if flyoutOpenOn(button) then
        EquipmentFlyout_Hide()
        return
    end
    -- If there's an item on the cursor after clicking or the slot is empty then open the flyout. The
    -- popout's own click handler sets its flyoutLocked, so Blizzard keeps its state.
    local cursorHasItem = _G.CursorHasItem
    local cursorItem = type(cursorHasItem) == "function" and Secrets.PlainTruth(cursorHasItem()) == true
    if cursorItem or not Compat.InventoryItemLink(button.id or button:GetID()) then
        if button.popoutButton then EquipmentFlyoutPopoutButton_OnClick(button.popoutButton) end
    end
end

-- Post-hook `settings[name]` with `fn` when the client has that function (hooksecurefunc raises on a
-- missing member).
local function hookFlyout(settings, name, fn)
    if type(settings[name]) ~= "function" then return end
    hooksecurefunc(settings, name, fn)
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
    local settings = PaperDollItemsFrame and PaperDollItemsFrame.flyoutSettings
    if type(settings) ~= "table" or type(hooksecurefunc) ~= "function" then return end
    hookFlyout(settings, "getItemsFunc", filterItems)
    hookFlyout(settings, "postGetItemsFunc", sortItems)
end

--- The lifecycle's stand-down (design §5.12): the hooks stay installed and their bodies read the
--- latch; only the clicked slot is forgotten.
function QS.Suspend()
    currentSlot = nil
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
