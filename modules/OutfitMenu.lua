local _, NS = ...
-- modules/OutfitMenu.lua — NS.OutfitMenu: the outfit context menu (design §7.5, INV §7.7).
--
-- Open(anchor, id) from a list row's right click or menu mark, and a bar button's right click. The
-- menu is written as a MenuUtil description `fill(root)` and drawn through NS.OpenMenu
-- (core/WidgetsSetup.lua): W.ContextMenu one level at a time, a submenu row opening its level in the
-- menu's place, and the client's MenuUtil on a degraded install. The library hides the menu before a
-- row's click runs, which retires the legacy 0.1 s / 0.2 s auto-hide; a toggle row (CreateCheckbox)
-- keeps it open and shows its new state.
--
-- FOUR SECTIONS, legacy's rows less Void Storage and the script editor (H1):
--   General     the name; Rename...; Key binding (None, Outfit 1-10 with each key's holder); Title
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
-- No label carries a glyph: a submenu's arrow and a toggle's tick are marks the seam draws.
-- Every write goes through its owner's seam: the instance rows through NS.SetByPath with the id, the
-- record flags and the binding through NS.Outfits.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits, NS.Stack.UpdateTitle, NS.Bank, NS.Stats,
-- NS.Triggers, NS.Popups, NS.OutfitDialog, NS.RebuildDialog, NS.TriggerDialog, NS.IconChooser.

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

-- ── General ───────────────────────────────────────────────────────────────────────────────────

local function fillBinding(root, id)
    local O = NS.Outfits
    local kb = root:CreateButton(L["Key binding"])
    kb:CreateButton(L["None"], function() O.SetBinding(id, nil) end)
    for n = 1, MAX_BINDING do
        local holder = O.Get(O.BoundTo(n))
        local label = holder and L["Outfit %d (%s)"]:format(n, tostring(holder.name or "")) or L["Outfit %d"]:format(n)
        kb:CreateButton(label, function() O.SetBinding(id, n) end)
    end
end

-- The title is shown half a second after the pick, as the legacy menu did; the menu click is the
-- hardware event the client wants.
local function setTitle(id, titleID)
    NS.Outfits.SetFlag(id, "titleID", titleID)
    C_Timer.After(TITLE_DELAY, function()
        if not NS.IsStoodDown() then NS.Stack.UpdateTitle(true) end
    end)
end

local function fillTitles(root, id)
    local level = root:CreateButton(L["Title"])
    level:CreateButton(L["None"], function() setTitle(id, nil) end)
    local n = 0
    for _, t in ipairs(Compat.KnownTitles()) do
        if n == TITLES_PER_LEVEL then
            level, n = level:CreateButton(L["More"]), 0
        end
        level:CreateButton(t.name, function() setTitle(id, t.id) end)
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
    root:CreateCheckbox(label, function() return NS.Outfits.Get(id)[flag] == true end,
        function() NS.Outfits.SetFlag(id, flag, NS.Outfits.Get(id)[flag] ~= true) end)
end

local function fillGeneral(root, rec)
    local id = rec.id
    root:CreateTitle(tostring(rec.name or ""))
    root:CreateButton(L["Rename..."], function() NS.OutfitDialog.OpenRename(id) end)
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

local function fillTriggerPicker(root, rec)
    local id = rec.id
    local desc = NS.Triggers.Get(rec.trigger and rec.trigger.id)
    local menu = root:CreateButton(L["Automation: %s"]:format(desc and desc.name or L["None"]))
    menu:CreateButton(L["No trigger"], function() pickTrigger(id, "") end)
    local classFile = Compat.PlayerClass()
    for _, cat in ipairs(NS.Triggers.Categories(classFile)) do
        local level = menu:CreateButton(OM.CategoryLabel(cat))
        for _, d in ipairs(NS.Triggers.List(cat, classFile)) do
            local b = level:CreateButton(d.name .. (hasParams(d) and "..." or ""), function() pickTrigger(id, d.id) end)
            b:SetTooltip(tip(d.desc))
        end
    end
end

-- A trigger flag as a toggle row, written through the instance row; disabled without a trigger.
local function triggerToggle(root, label, id, flag, enabled)
    local path = "outfit.trigger." .. flag
    local function on()
        local t = NS.Outfits.Get(id).trigger
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
    local has = rec.trigger ~= nil and rec.trigger.id ~= nil
    triggerToggle(root, L["Turn trigger off"], id, "disabled", has)
    triggerToggle(root, L["Disable outfit in combat"], id, "combatDisabled", has)
end

-- ── Outfit bar ────────────────────────────────────────────────────────────────────────────────

local function fillBar(root, rec, anchor)
    local id = rec.id
    root:CreateDivider()
    local function shown()
        local bar = NS.Outfits.Get(id).bar
        return not (bar and bar.hide)
    end
    root:CreateCheckbox(L["Show in outfit bar"], shown,
        function() NS.SetByPath("outfit.bar.hide", shown(), id) end)
    root:CreateButton(L["Change icon..."], function() NS.IconChooser.Open(id, anchor) end)
end

--- Open the context menu for outfit `id` at the cursor.
--- @param anchor table the frame the menu belongs to (a row, its menu mark, a bar button)
--- @param id string
--- @return boolean opened
function OM.Open(anchor, id)
    if NS.IsStoodDown() then return false end
    local rec = NS.Outfits.Get(id)
    if not rec then return false end
    return NS.OpenMenu(anchor, function(root)
        fillGeneral(root, rec)
        fillRebuild(root, rec)
        fillAutomation(root, rec)
        fillBar(root, rec, anchor)
    end) == true
end
