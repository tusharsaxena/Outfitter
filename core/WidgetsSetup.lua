local addonName, NS = ...
-- core/WidgetsSetup.lua — NS.MakeDropdown / NS.OpenMenu / NS.CloseMenu / NS.MakeTestStrip from LibKa0s-Widgets-1.0 (BP §6.13).
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
-- button SetEnabled and a nested CreateButton), recorded here, then handed whole to W.ContextMenu:
-- a button with a nested level becomes a `submenu` row, which the library (Widgets minor 23) opens
-- beside its row with the parent kept drawn. Without the library the same `fill` goes to the
-- client's MenuUtil, which cascades natively. The library hides every level before a row's click
-- runs, which retires the old 0.1/0.2 s auto-hide.
--
-- KEEP-OPEN OR ACT-AND-CLOSE (design 2026-11-05 G4). A CreateCheckbox (a toggle) and a CreateRadio
-- (one choice of several, ticked) keep every level open; anything else closes them, because a row
-- that opens a dialog, popup or window would sit under the FULLSCREEN_DIALOG menu. On the client's
-- menu that is the responder's answer: MenuResponse.Refresh from the keep-open rows, nil (close all)
-- from the rest.

--- A level of a description: the recorder a `fill` writes to, and each button's own nested level.
--- Beside MenuUtil's CreateTitle and CreateButton it records CreateDivider, CreateCheckbox and
--- CreateRadio (keep-open rows) and a row's SetTooltip, each under MenuUtil's own name and shape, so
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
        -- MenuUtil's tooltip is `fn(tooltip, description)`; it is read into plain text at each paint.
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
    --- A choice row: as a toggle, drawn as a radio with the menu's tick on the current choice.
    function level:CreateRadio(text, isSelected, setSelected, data)
        local sub = self:CreateCheckbox(text, isSelected, setSelected, data)
        sub.radio = true
        return sub
    end
    return level
end

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

-- A row's label: a toggle's carries its tick when selected; a radio's tick is the library's column.
local function rowLabel(item)
    if item.isSelected and not item.radio and item.isSelected(item.data) then
        return NS.Skin.MarkText(NS.Icon("confirm"), 0) .. " " .. item.label
    end
    return item.label
end

--- Write a recorded item's state onto its W.ContextMenu row: label, disabled state, tooltip, and a
--- radio's tick predicate. The library reads these on every paint.
local function paintRow(out, item)
    out.label = rowLabel(item)
    if item.title then return end
    out.disabled = item.enabled == false or nil
    out.tooltip = tooltipText(item)
    if item.radio then out.selected = function() return item.isSelected(item.data) and true or false end end
end

--- After a keep-open pick: the fill written again (`level`, the fresh root) onto the open rows, so
--- every level the library repaints reads the new labels, ticks and disabled states (a parent's
--- "Automation: X", a key's holder). A level whose shape moved keeps what it had, its keep-open
--- rows repainted from their own items first (NS.OpenMenu's refresh).
local function relabel(rows, level)
    if #rows ~= #level.items then return end
    for i, out in ipairs(rows) do
        local item = level.items[i]
        if (item.divider == true) ~= (out.divider == true) or (item.title == true) ~= (out.title == true) then return end
        if not item.divider then paintRow(out, item) end
        if out.submenu and #item.items > 0 then relabel(out.submenu, item) end
    end
end

local buildRows

--- One W.ContextMenu row: a title, a divider, a submenu row carrying its level, a keep-open toggle or
--- radio, or a button with its click. `menu.refresh` rewrites the whole open tree after a keep-open pick.
local function menuRow(item, menu)
    if item.title then return { label = item.label, title = true } end
    if item.divider then return { divider = true } end
    local out = {}
    paintRow(out, item)
    if item.isSelected then
        out.keepOpen, out.radio = true, item.radio or nil
        menu.own[#menu.own + 1] = { out = out, item = item }
        out.onClick = function()
            item.setSelected(item.data)
            menu.refresh()
        end
    elseif #item.items > 0 then
        out.submenu = buildRows(item, menu)
    else
        out.onClick = item.onClick
    end
    return out
end

buildRows = function(level, menu)
    local rows = {}
    for i, item in ipairs(level.items) do rows[i] = menuRow(item, menu) end
    return rows
end

-- The value a keep-open row's responder answers on the client's menu: Refresh, guarded, since a
-- client without MenuResponse is one where nil (close all) is the only safe answer.
local function refreshResponse()
    local R = MenuResponse
    return R and R.Refresh or nil
end

--- The client's description, wrapped so a toggle or radio answers Refresh and keeps the menu open,
--- and every button answers nil and closes it, at any depth. Every other method passes through.
local function wrapDescription(desc)
    local w = setmetatable({}, { __index = function(_, k)
        return function(_, ...) return desc[k](desc, ...) end
    end })
    function w.CreateButton(_, text, onClick)
        local cb = onClick and function(...) onClick(...) end
        return wrapDescription(desc:CreateButton(text, cb))
    end
    local function keepOpen(method)
        return function(_, text, isSelected, setSelected, data)
            local function set(...)
                setSelected(...)
                return refreshResponse()
            end
            return wrapDescription(desc[method](desc, text, isSelected, set, data))
        end
    end
    w.CreateCheckbox, w.CreateRadio = keepOpen("CreateCheckbox"), keepOpen("CreateRadio")
    return w
end

--- A context menu at the cursor: `fill(root)` adds its rows as it would to a MenuUtil description.
--- @param anchor table the region the menu belongs to (a press on it is no outside press)
--- @param fill function
--- @return boolean opened  false when neither the library nor the client's MenuUtil can draw one
function NS.OpenMenu(anchor, fill)
    if not W then
        if not (MenuUtil and MenuUtil.CreateContextMenu) then return false end
        MenuUtil.CreateContextMenu(anchor, function(_, root) fill(wrapDescription(root)) end)
        return true
    end
    local level = newLevel()
    fill(level)
    local menu = { own = {} }
    local rows = buildRows(level, menu)
    function menu.refresh()
        -- Every toggle and radio from its own item: a pick may move another's tick (wearing a
        -- Complete outfit takes the others off), as MenuUtil re-reads each checkbox.
        for _, o in ipairs(menu.own) do paintRow(o.out, o.item) end
        local fresh = newLevel()
        fill(fresh)
        relabel(rows, fresh)
    end
    W.ContextMenu(anchor, rows, { owner = addonName, cursor = true })
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
