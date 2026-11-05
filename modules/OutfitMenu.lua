local _, NS = ...
-- modules/OutfitMenu.lua — NS.OutfitMenu: the outfit context menu (design §7.5, INV §7.7).
--
-- Open(anchor, id) from a list row's right click or menu mark, and a bar button's right click. The
-- menu is written as a MenuUtil description `fill(root)` and drawn through NS.OpenMenu
-- (core/WidgetsSetup.lua): W.ContextMenu with the whole tree, each nested level opening beside its
-- parent with the parent kept (Widgets minor 23), and the client's MenuUtil on a degraded install.
-- The library hides the menu before a row's click runs, which retires the legacy 0.1 s / 0.2 s
-- auto-hide.
--
-- KEEP-OPEN OR ACT-AND-CLOSE (design 2026-11-05 G4). A choice made in place keeps the menu open and
-- ticks the current one: the toggles (CreateCheckbox) and the radios (CreateRadio) of Save in
-- equipment manager, Key binding, Title and a trigger without settings, after which every open level shows its new labels. A row
-- that opens a dialog, popup or window (Rename, Delete, Update, Rebuild, Trigger settings, Change
-- icon, a trigger with settings) closes it, and so do the bank moves.
--
-- FOUR SECTIONS, legacy's rows less Void Storage and the script editor (H1):
--   General     the name; Rename...; Save in equipment manager (On and Off: NS.EM.SetStored, the
--               outfit row's EM mark's own path, smoke round 3 E12); Key binding (None, Outfit 1-10 with each key's holder); Title
--               (None and the known titles, 30 a level and then More); Bank (each row disabled, with
--               the reason, while the bank is closed); Unequip others (not on a Complete outfit);
--               Ignore comparisons; Delete (asks first).
--   Rebuild     Update to current items (asks); Rebuild for <stat> (only with a stat cfg; asks);
--               Rebuild for... (the rebuild dialog).
--   Automation  Automation: <trigger or None> (No trigger, then one level per picker category, "..."
--               on a trigger with settings, its description as the tooltip); Trigger settings...;
--               Turn trigger off and Disable outfit in combat, disabled without a trigger.
--   Outfit bar  Show in outfit bar; Change icon... (one ellipsis: the legacy label doubled it).
--
-- A SAMPLE'S MENU (test mode, smoke round 3 E4). While NS.Preview is on, a sample outfit's gear opens
-- the same four sections for its `preview:<n>` record (NS.PreviewOutfits.Get), written to a
-- browse-only level (browseOnly below): titles, dividers and the submenu rows pass through, so every
-- level cascades as usual, and every row that would change data is built DISABLED around a no-op,
-- with the tooltip L["Not available in test mode"], whatever the fill does to it afterwards. No click
-- is ever handed a seam, so nothing reaches a real outfit; the reads (a key's holder, the titles) are
-- the live ones. A real outfit's menu is untouched by test mode.
--
-- No label carries a glyph: a submenu's arrow and a toggle's tick are marks the seam draws.
-- Every write goes through its owner's seam: the instance rows through NS.SetByPath with the id, the
-- record flags and the binding through NS.Outfits.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits, NS.EM.SetStored/Current, NS.Stack.UpdateTitle,
-- NS.Bank, NS.Stats,
-- NS.Triggers, NS.Popups, NS.OutfitDialog, NS.RebuildDialog, NS.TriggerDialog, NS.IconBrowser,
-- NS.Preview.IsActive, NS.PreviewOutfits.Get.

local OM = {}
NS.OutfitMenu = OM

local L = NS.L
local Compat = NS.Compat

local MAX_BINDING = 10
local TITLES_PER_LEVEL = 30
local TITLE_DELAY = 0.5

--- A picker category's label: the class reads the client's own class name (already in the player's
--- gender form), the rest their own words (legacy cScriptCategoryName).
--- @param category string
--- @return string
function OM.CategoryLabel(category)
    if category == "CLASS" then return Compat.PlayerClassName() or L["Class"] end
    local labels = { GENERAL = L["General"], TRADE = L["Activities"], PVP = L["PvP"], QUEST = L["Questing"],
                     ENTERTAIN = L["Entertainment"], SPEC = L["Specialization"] }
    return labels[category] or tostring(category)
end

local function tip(text)
    return function(tooltip) tooltip:SetText(text) end
end

-- The outfit's record, or an empty one once it is gone: the menu stays open across keep-open picks
-- and the library reads each tick on every paint, while the Equipment Manager sync can prune the
-- outfit from under it. Every write still goes through a seam that refuses an unknown id.
local NO_RECORD = {}
local function recOf(id) return NS.Outfits.Get(id) or NO_RECORD end

-- ── General ───────────────────────────────────────────────────────────────────────────────────

-- Save in equipment manager: On and Off, the EM mark's click (NS.EM.SetStored). A store makes a new
-- record, so both radios follow the outfit to it (NS.EM.Current) and tick its true state; a sample's
-- tick is its drawn `em`.
local function fillEM(root, rec)
    local id = rec.id
    local function stored()
        local live = NS.Outfits.Get(NS.EM.Current(id))
        if live then return live.kind == "em" end
        return rec.em == true
    end
    local function set(on) NS.EM.SetStored(NS.EM.Current(id), on) end
    local level = root:CreateButton(L["Save in equipment manager"])
    level:CreateRadio(L["On"], stored, set, true)
    level:CreateRadio(L["Off"], function() return not stored() end, set, false)
end

local function fillBinding(root, id)
    local O = NS.Outfits
    local kb = root:CreateButton(L["Key binding"])
    local function bound(n) return O.BindingOf(id) == n end
    local function bind(n) O.SetBinding(id, n) end
    kb:CreateRadio(L["None"], function() return bound(nil) end, function() bind(nil) end)
    for n = 1, MAX_BINDING do
        local holder = O.Get(O.BoundTo(n))
        local label = holder and L["Outfit %d (%s)"]:format(n, tostring(holder.name or "")) or L["Outfit %d"]:format(n)
        kb:CreateRadio(label, bound, bind, n)
    end
end

-- The title is shown half a second after the pick, as the legacy menu did; the menu click is the
-- hardware event the client wants. The delay rides NS.addon's AceTimer, so the stand-down's
-- CancelAllTimers takes it (slash-commands-§7); C_Timer.After only without AceTimer, where the
-- stood-down gate below keeps it inert.
local function setTitle(id, titleID)
    NS.Outfits.SetFlag(id, "titleID", titleID)
    local function show()
        if not NS.IsStoodDown() then NS.Stack.UpdateTitle(true) end
    end
    local addon = NS.addon
    if addon and addon.ScheduleTimer then
        addon:ScheduleTimer(show, TITLE_DELAY)
    else
        C_Timer.After(TITLE_DELAY, show)
    end
end

local function fillTitles(root, id)
    local level = root:CreateButton(L["Title"])
    local function worn(titleID) return recOf(id).titleID == titleID end
    local function pick(titleID) setTitle(id, titleID) end
    level:CreateRadio(L["None"], function() return worn(nil) end, function() pick(nil) end)
    local n = 0
    for _, t in ipairs(Compat.KnownTitles()) do
        if n == TITLES_PER_LEVEL then
            level, n = level:CreateButton(L["More"]), 0
        end
        level:CreateRadio(t.name, worn, pick, t.id)
        n = n + 1
    end
end

-- The bank rows: { label, member, uniqueOnly } or "-" for the divider.
local BANK_ROWS = {
    { L["Deposit all items to bank"], "Deposit" }, { L["Deposit unique items to bank"], "Deposit", true },
    { L["Withdraw items from bank"], "Withdraw" }, "-",
    { L["Deposit other outfits to bank"], "DepositOthers" }, { L["Withdraw other outfits from bank"], "WithdrawOthers" },
}

local function bankMove(id, row)
    local ok, why = NS.Bank[row[2]](id, row[3])
    if not ok and why then NS.Print(why) end
end

local function fillBank(root, id)
    local bank = root:CreateButton(L["Bank"])
    local open = NS.Bank.IsOpen()
    for _, row in ipairs(BANK_ROWS) do
        if row == "-" then
            bank:CreateDivider()
        else
            local b = bank:CreateButton(row[1], function() bankMove(id, row) end)
            b:SetEnabled(open)
            if not open then b:SetTooltip(tip(L["The bank must be open"])) end
        end
    end
end

-- A record flag as a toggle row.
local function flagToggle(root, label, id, flag)
    root:CreateCheckbox(label, function() return recOf(id)[flag] == true end,
        function() NS.Outfits.SetFlag(id, flag, recOf(id)[flag] ~= true) end)
end

local function fillGeneral(root, rec)
    local id = rec.id
    root:CreateTitle(tostring(rec.name or ""))
    root:CreateButton(L["Rename..."], function() NS.OutfitDialog.OpenRename(id) end)
    fillEM(root, rec)
    fillBinding(root, id)
    fillTitles(root, id)
    fillBank(root, id)
    if rec.category ~= "Complete" then
        flagToggle(root, L["On equip, unequip other Accessory outfits"], id, "unequipOthers")
    end
    flagToggle(root, L["Ignore in comparison tooltips"], id, "ignoreComparisons")
    root:CreateButton(L["Delete"], function() NS.Popups.ShowDelete(id) end)
end

-- ── Rebuild ───────────────────────────────────────────────────────────────────────────────────

local function fillRebuild(root, rec)
    local id = rec.id
    root:CreateDivider()
    root:CreateButton(L["Update to current items"], function() NS.Popups.ShowSetCurrent(id) end)
    local statName = rec.stat and NS.Stats.ConfigName(rec.stat)
    if statName then
        root:CreateButton(L["Rebuild for %s"]:format(statName), function() NS.Popups.ShowRebuild(id, rec.stat) end)
    end
    root:CreateButton(L["Rebuild for..."], function() NS.RebuildDialog.Open(id) end)
end

-- ── Automation ────────────────────────────────────────────────────────────────────────────────

local function hasParams(desc) return desc ~= nil and #(desc.params or {}) > 0 end

local function pickTrigger(id, tid)
    if not NS.SetByPath("outfit.trigger.id", tid, id) then return end
    if hasParams(NS.Triggers.Get(tid)) then NS.TriggerDialog.Open(id) end
end

-- The outfit's trigger id, or "" without one (the No trigger row's value).
local function triggerOf(id)
    local t = recOf(id).trigger
    return t and t.id or ""
end

-- One trigger pick: a trigger with settings acts and closes (its dialog opens); one without is a
-- radio that keeps the menu open.
local function triggerRow(level, id, d)
    local b
    if hasParams(d) then
        b = level:CreateButton(d.name .. "...", function() pickTrigger(id, d.id) end)
    else
        b = level:CreateRadio(d.name, function() return triggerOf(id) == d.id end,
            function() pickTrigger(id, d.id) end)
    end
    b:SetTooltip(tip(d.desc))
end

local function fillTriggerPicker(root, rec)
    local id = rec.id
    local desc = NS.Triggers.Get(triggerOf(id))
    local menu = root:CreateButton(L["Automation: %s"]:format(desc and desc.name or L["None"]))
    menu:CreateRadio(L["No trigger"], function() return triggerOf(id) == "" end, function() pickTrigger(id, "") end)
    local classFile = Compat.PlayerClass()
    for _, cat in ipairs(NS.Triggers.Categories(classFile)) do
        local level = menu:CreateButton(OM.CategoryLabel(cat))
        for _, d in ipairs(NS.Triggers.List(cat, classFile)) do triggerRow(level, id, d) end
    end
end

-- A trigger flag as a toggle row, written through the instance row; disabled without a trigger.
local function triggerToggle(root, label, id, flag, enabled)
    local path = "outfit.trigger." .. flag
    local function on()
        local t = recOf(id).trigger
        return t ~= nil and t[flag] == true
    end
    local row = root:CreateCheckbox(label, on, function() NS.SetByPath(path, not on(), id) end)
    row:SetEnabled(enabled)
end

local function fillAutomation(root, rec)
    local id = rec.id
    root:CreateDivider()
    fillTriggerPicker(root, rec)
    root:CreateButton(L["Trigger settings..."], function() NS.TriggerDialog.Open(id) end)
    local has = triggerOf(id) ~= ""
    triggerToggle(root, L["Turn trigger off"], id, "disabled", has)
    triggerToggle(root, L["Disable outfit in combat"], id, "combatDisabled", has)
end

-- ── Outfit bar ────────────────────────────────────────────────────────────────────────────────

local function fillBar(root, rec)
    local id = rec.id
    root:CreateDivider()
    local function shown()
        local bar = recOf(id).bar
        return not (bar and bar.hide)
    end
    root:CreateCheckbox(L["Show in outfit bar"], shown,
        function() NS.SetByPath("outfit.bar.hide", shown(), id) end)
    root:CreateButton(L["Change icon..."], function() NS.IconBrowser.Open(id) end)
end

-- ── test mode: browse only (smoke round 3 E4) ─────────────────────────────────────────────────

local function noop() end

-- A data row, built off around a no-op: its own SetEnabled and SetTooltip calls are swallowed, so a
-- fill that enables a row later (the bank's, with the bank open) cannot turn it back on.
local INERT = setmetatable({}, { __index = function() return noop end })

local function inert(row)
    row:SetEnabled(false)
    row:SetTooltip(tip(L["Not available in test mode"]))
    return INERT
end

--- `level` (the seam's recorder or the client's description) as a browse-only level: see the header.
--- @param level table
--- @return table
local function browseOnly(level)
    local w = setmetatable({}, { __index = function(_, k)
        local v = level[k]
        if type(v) ~= "function" then return v end
        return function(_, ...) return v(level, ...) end
    end })
    function w.CreateButton(_, text, onClick)
        if onClick == nil then return browseOnly(level:CreateButton(text)) end
        return inert(level:CreateButton(text, noop))
    end
    function w.CreateCheckbox(_, text, isSelected, _, data)
        return inert(level:CreateCheckbox(text, isSelected, noop, data))
    end
    function w.CreateRadio(_, text, isSelected, _, data)
        return inert(level:CreateRadio(text, isSelected, noop, data))
    end
    return w
end

local function fillAll(root, rec)
    fillGeneral(root, rec)
    fillRebuild(root, rec)
    fillAutomation(root, rec)
    fillBar(root, rec)
end

-- The sample record behind `id` while test mode is on, else nil.
local function sampleOf(id)
    if NS.Preview.IsActive() ~= true then return nil end
    return NS.PreviewOutfits.Get(id)
end

--- Open the context menu for outfit `id` at the cursor.
--- @param anchor table the frame the menu belongs to (a row, its menu mark, a bar button)
--- @param id string
--- @return boolean opened
function OM.Open(anchor, id)
    if NS.IsStoodDown() then return false end
    local sample = sampleOf(id)
    if sample then
        return NS.OpenMenu(anchor, function(root) fillAll(browseOnly(root), sample) end) == true
    end
    if not NS.Outfits.Get(id) then return false end
    -- The record is read on every fill: a keep-open pick fills the menu again to relabel it. A fill
    -- after the outfit is gone adds nothing, and the open rows keep what they show.
    return NS.OpenMenu(anchor, function(root)
        local rec = NS.Outfits.Get(id)
        if not rec then return end
        fillAll(root, rec)
    end) == true
end
