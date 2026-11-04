local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDropdown / NS.OpenMenu / NS.CloseMenu / NS.MakeTestStrip / NS.MakeDragHandle from LibKa0s-Widgets-1.0 (BP §6.13).
--
-- A seam, nothing else (library-stack-§7): one file leases the major, so the art the controls draw
-- is resolved once, here, and every control is handed this addon's skin owner. The library is
-- vendored and cannot know which folder it was copied into, so the chevrons, the tick and the info
-- mark arrive as resolved paths from the media seam (core/MediaSetup.lua); NS.Icon answering nil is
-- a real answer, and the library falls back to the Blizzard art.
--
-- The users, as they land in P4: the outfit context menu (modules/OutfitMenu.lua, through
-- NS.OpenMenu; it replaces LibDropdown and the MC2 menus, design §7.5), the dialogs' dropdowns
-- (NS.MakeDropdown, §7.6) and the outfit bar's test strip (NS.MakeTestStrip, §7.7, H17). The seam
-- exports no copy window: the diagnostics report is copied from the debug console's own Copy button.
--
-- THE POPUP IS A PROCESS-WIDE SINGLETON parented to UIParent, so hiding a window does not reach it.
-- Every non-click close path of a window that opens a menu calls NS.CloseMenu(): the character
-- sheet's OnHide, the outfit window's OnHide and each dialog's OnHide (design §7.2, §7.3, §7.6).
--
-- DEGRADED (the library absent): NS.MakeDropdown and NS.MakeTestStrip answer nil, and the caller
-- draws no control rather than a dead one; NS.OpenMenu hands the same `fill` to the client's
-- MenuUtil; NS.CloseMenu is a no-op, because no Ka0s menu can be open.

local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

--- One flat-skin dropdown, or nil when the library is absent. Nil is a real answer: the caller
--- draws no control.
--- @param parent table the frame to parent it to
--- @param width number the collapsed button's width
--- @return table|nil
function NS.MakeDropdown(parent, width)
    if not W then return nil end
    return W.Dropdown(parent, width, {
        chevron = NS.Icon("chevron-down"),
        check   = NS.Icon("confirm"),
        owner   = addonName,
    })
end

-- ── the context menus ────────────────────────────────────────────────────────────────────────────
-- A `fill(root)` is written against MenuUtil's own description (CreateTitle, CreateButton, and on a
-- button SetEnabled and a nested CreateButton), recorded here, then drawn through W.ContextMenu
-- (Widgets minor 21) one level at a time: that menu has no flyout, so a submenu's row opens its own
-- rows in the menu's place. Without the library the same `fill` goes to the client's menu. The
-- library hides the menu before a row's click runs, which retires the old 0.1/0.2 s auto-hide.

--- A level of a description: the recorder a `fill` writes to, and each button's own nested level.
--- Beside MenuUtil's CreateTitle and CreateButton it records CreateDivider, CreateCheckbox (a toggle
--- row that keeps the menu open) and a row's SetTooltip, each under MenuUtil's own name and shape, so
--- the client's menu reads the same `fill` on the degraded arm.
local function newLevel()
    local level = { items = {} }
    function level:CreateTitle(text)
        self.items[#self.items + 1] = { label = text, title = true }
        return {}
    end
    function level:CreateDivider()
        self.items[#self.items + 1] = { divider = true }
        return {}
    end
    local function row(self, text, onClick)
        local sub = newLevel()
        sub.label, sub.onClick, sub.enabled = text, onClick, true
        function sub.SetEnabled(_, on) sub.enabled = on and true or false end
        -- MenuUtil's tooltip is `fn(tooltip, description)`; it is read once, here, into plain text.
        function sub.SetTooltip(_, fn) sub.tooltip = fn end
        self.items[#self.items + 1] = sub
        return sub
    end
    function level:CreateButton(text, onClick) return row(self, text, onClick) end
    --- A toggle row: `isSelected(data)` draws its tick, `setSelected(data)` flips it, and the menu stays.
    function level:CreateCheckbox(text, isSelected, setSelected, data)
        local sub = row(self, text, nil)
        sub.isSelected, sub.setSelected, sub.data = isSelected, setSelected, data
        return sub
    end
    return level
end

local showLevel

-- A row's tooltip as plain text: the recorded MenuUtil-shaped function, handed a capture of the one
-- tooltip call it makes.
local function tooltipText(item)
    if type(item.tooltip) ~= "function" then return nil end
    local text
    local capture = {}
    function capture.SetText(_, t) text = t end
    function capture.AddLine(_, t) text = text and (text .. "\n" .. t) or t end
    item.tooltip(capture, item)
    return text
end

-- A toggle row's label: its tick when selected.
local function checkLabel(item)
    if item.isSelected(item.data) then return NS.Skin.MarkText(NS.Icon("confirm"), 0) .. " " .. item.label end
    return item.label
end

local function checkRow(item, out)
    out.label, out.keepOpen = checkLabel(item), true
    out.onClick = function()
        item.setSelected(item.data)
        out.label = checkLabel(item)
    end
    return out
end

--- One W.ContextMenu row: a title, a divider, or a button with its click, a submenu's mark, its
--- disabled state and its tooltip.
local function menuRow(anchor, item)
    if item.title then return { label = item.label, title = true } end
    if item.divider then return { divider = true } end
    local out = { disabled = item.enabled == false or nil, tooltip = tooltipText(item) }
    if item.isSelected then return checkRow(item, out) end
    local isSubmenu = #item.items > 0
    out.label = item.label
    if isSubmenu then out.label = out.label .. " " .. NS.Skin.MarkText(NS.Icon("chevron-right"), 0) end
    out.onClick = isSubmenu and function() showLevel(anchor, item) end or item.onClick
    return out
end

--- Open `level` at the cursor. The library hides the menu before a row's click, so a submenu's row
--- may open the next level from its own callback.
showLevel = function(anchor, level)
    local rows = {}
    for i, item in ipairs(level.items) do rows[i] = menuRow(anchor, item) end
    W.ContextMenu(anchor, rows, { owner = addonName, cursor = true })
end

--- A context menu at the cursor: `fill(root)` adds its rows as it would to a MenuUtil description.
--- @param anchor table the region the menu belongs to (a press on it is no outside press)
--- @param fill function
--- @return boolean opened  false when neither the library nor the client's MenuUtil can draw one
function NS.OpenMenu(anchor, fill)
    if not W then
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
        MenuUtil.CreateContextMenu(anchor, function(_, root) fill(root) end)
        return true
    end
    local level = newLevel()
    fill(level)
    showLevel(anchor, level)
    return true
end

--- An icon as inline markup for a line of text, cropped by the library's icon rule (W.IconText):
--- the Outfits broker's menu rows. `size` 0 is the line's height. "" without the library or an icon.
--- @param icon number|string|nil
--- @param size number|nil
--- @return string
function NS.IconText(icon, size)
    if not (W and W.IconText) or icon == nil then return "" end
    return W.IconText(icon, size or 0)
end

--- Close the shared popup menu behind every dropdown and context menu in the process, if one is
--- open. Safe when none ever opened, and a no-op on a degraded install.
function NS.CloseMenu()
    if W then W.CloseMenu() end
end

-- ── the test-mode strip ──────────────────────────────────────────────────────────────────────────

--- The strip's height, for a surface laying its content out below it (the library publishes it).
NS.TEST_STRIP_HEIGHT = (W and W.TEST_STRIP and W.TEST_STRIP.HEIGHT) or 18

--- Test mode's own end, for the strip's right-click menu: modules/Preview.lua, reached at call time.
local function endTestMode()
    local P = NS.Preview
    if P and P.IsActive and P.IsActive() and P.Stop then P.Stop() end
end

--- The test-mode strip (the library's W.TestStrip, born hidden and unanchored), or nil when the
--- library is absent. The caller anchors it and shows it. Its mark is the catalog's info icon and its
--- right-click ends test mode.
--- @param parent table the frame to parent it to
--- @param label string the localized line it says
--- @param opts table|nil any further W.TestStrip option (`kind`, `panel`, `L`, `onEnd`), which wins
--- @return table|nil
function NS.MakeTestStrip(parent, label, opts)
    if not W then return nil end
    local o = { text = label, icon = NS.Icon("info"), owner = addonName, onEnd = endTestMode }
    if type(opts) == "table" then
        for k, v in pairs(opts) do o[k] = v end
    end
    return W.TestStrip(parent, o)
end

-- ── the drag handle ──────────────────────────────────────────────────────────────────────────────

--- The unlocked drag strip over a movable frame (the library's W.DragHandle, born hidden and
--- unanchored), or nil when the library is absent: the frame then simply has no strip. Its help mark
--- is the catalog's help icon and its colors follow this addon's skin owner. The outfit bar's (§7.7).
--- @param parent table the frame to parent it to
--- @param spec table W.DragHandle's spec (`label` and `moveFrame` required); its own fields win
--- @return table|nil
function NS.MakeDragHandle(parent, spec)
    if not (W and W.DragHandle) then return nil end
    local o = { helpIcon = NS.Icon("help"), owner = addonName }
    if type(spec) == "table" then
        for k, v in pairs(spec) do o[k] = v end
    end
    return W.DragHandle(parent, o)
end
