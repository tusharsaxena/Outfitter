local _, NS = ...
-- modules/Dialog_Outfit.lua — NS.OutfitDialog: the new-outfit and rename dialog (design §7.6, INV §7.9).
--
-- NEW (OpenNew, the window's footer button). A name; a trigger picked in two dropdowns, its category
-- and then the trigger, because one flat menu of some seventy triggers does not fit on a screen; and
-- what the outfit is built from: Empty, Current items (the default) or Best for <stat>, the last
-- through the optimizer. Picking a trigger fills the name while the name is empty or still the last
-- auto-fill. Done refuses an empty name (the button is disabled), a used name ("That name is already
-- used") and a stat no item has (NS.Optimize.Trial's own line), each on the error line; on a pass it
-- creates the outfit (`opts.fields = { stat = cfg }` for a stat build, so Rebuild reads it), wears it
-- at once with `hw`, writes the trigger through NS.SetByPath and, when the trigger has settings,
-- opens the trigger dialog (INV §7.7).
--
-- RENAME (OpenRename, the menu's Rename...). The name field only, 140 px shorter; Done is
-- NS.Outfits.Rename, whose refusal is the error line.
--
-- The trigger's category is the PICKER's (General, Activities, ...), not the outfit's: an outfit is
-- Complete or Accessory by its items (NS.Outfits.Categorize).
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Create/Rename/FindByName/Get,
-- NS.Stack.Wear, NS.Triggers.Get/List/Categories, NS.OutfitMenu.CategoryLabel, NS.Optimize.Trial/
-- Generate, NS.ProgressDialog.Install, NS.Stats.Categories, NS.TriggerDialog.Open, NS.ItemInfo.

local OD = {}
NS.OutfitDialog = OD

local L = NS.L
local D = NS.Dialogs

local WIDTH, HEIGHT, RENAME_SHORTER = 340, 250, 140
local BUILDS = { "empty", "current", "stat" }

local frame
local st = { mode = "new", category = "GENERAL", trigger = "", build = "current", stat = "STA" }

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function nameText() return trim(frame.name:GetText()) end

local function setError(text) frame.error:SetText(text or "") end

local function updateDone()
    frame.done:SetEnabled(nameText() ~= "")
end

-- ── the pickers ───────────────────────────────────────────────────────────────────────────────

local function hasParams(desc)
    return desc ~= nil and #(desc.params or {}) > 0
end

--- The trigger rows of one picker category, "..." marking a trigger with settings (INV §7.7).
local function triggerOptions(category)
    local out = { { value = "", label = L["No trigger"] } }
    for _, d in ipairs(NS.Triggers.List(category, NS.Compat.PlayerClass())) do
        out[#out + 1] = { value = d.id, label = d.name .. (hasParams(d) and "..." or ""), tooltip = d.desc }
    end
    return out
end

local function categoryOptions()
    local out = {}
    for _, cat in ipairs(NS.Triggers.Categories(NS.Compat.PlayerClass())) do
        out[#out + 1] = { value = cat, label = NS.OutfitMenu.CategoryLabel(cat) }
    end
    return out
end

--- Every stat the optimizer knows, under its category's title.
local function statOptions()
    local out = {}
    for _, cat in ipairs(NS.Stats.Categories()) do
        out[#out + 1] = { label = cat.label, title = true }
        for _, stat in ipairs(cat.stats()) do out[#out + 1] = { value = stat.id, label = stat.label } end
    end
    return out
end

local function pick(dd, value)
    if dd then dd:SelectValue(value) end
end

--- The trigger dropdown's category.
function OD.SetCategory(category)
    st.category = category
    if frame and frame.trigger then frame.trigger:SetOptions(triggerOptions(category)) end
    pick(frame and frame.category, category)
end

--- Pick a trigger ("" is none). The name follows while it is empty or the previous auto-fill.
function OD.SetTrigger(tid)
    st.trigger = tid or ""
    local desc = NS.Triggers.Get(st.trigger)
    pick(frame.trigger, st.trigger)
    if desc then
        local name = nameText()
        if name == "" or name == st.autoName then
            st.autoName = desc.name
            frame.name:SetText(desc.name)
        end
    end
end

--- What the outfit is built from: "empty", "current" or "stat".
function OD.SetBuild(kind)
    st.build = kind
    for _, k in ipairs(BUILDS) do frame.radios[k]:SetChecked(k == kind) end
end

--- The stat a "stat" build optimizes for.
function OD.SetStat(statID)
    st.stat = statID
    pick(frame.stat, statID)
end

-- ── done ──────────────────────────────────────────────────────────────────────────────────────

local function wornItems()
    local items = {}
    for _, slot in ipairs(NS.ItemData.SLOT_NAMES) do
        local info = NS.ItemInfo.FromSlot(slot)
        items[slot] = info and NS.ItemInfo.Snapshot(info) or { id = 0 }
    end
    return items
end

-- Create, wear, trigger, and the trigger's settings when it has any (design §7.6 Done).
local function finish(name, items, tid, opts)
    local id = NS.Outfits.Create(name, items, opts)
    NS.Stack.Wear(id, { hw = true })
    if tid ~= "" then
        NS.SetByPath("outfit.trigger.id", tid, id)
        if hasParams(NS.Triggers.Get(tid)) then NS.TriggerDialog.Open(id) end
    end
    return id
end

-- A stat build: the optimizer's items, delivered once (now for a simple search, later for a genetic one).
local function buildForStat(name, tid)
    local cfg = { { stat = st.stat } }
    local ok, msg = NS.Optimize.Trial(cfg)
    if not ok then return false, msg end
    NS.ProgressDialog.Install()
    local job, err = NS.Optimize.Generate(name, cfg, {}, function(items, reason)
        if items then return finish(name, items, tid, { fields = { stat = cfg } }) end
        if reason == "empty" then NS.Print(L["Couldn't generate an outfit because no items with that stat were found"]) end
    end)
    if not job then return false, err end
    return true
end

local function doneNew(name)
    if NS.Outfits.FindByName(name) then return false, L["That name is already used"] end
    if st.build == "stat" then return buildForStat(name, st.trigger) end
    finish(name, st.build == "current" and wornItems() or {}, st.trigger)
    return true
end

--- Done: create (or rename). False, with the reason on the error line, when refused.
--- @return boolean
function OD.Done()
    if not (frame and frame:IsShown()) or NS.IsStoodDown() then return false end
    local name = nameText()
    if name == "" then return false end
    local ok, why
    if st.mode == "rename" then
        ok, why = NS.Outfits.Rename(st.id, name)
    else
        ok, why = doneNew(name)
    end
    if not ok then
        setError(why)
        return false
    end
    frame:Hide()
    return true
end

-- ── the frame ─────────────────────────────────────────────────────────────────────────────────

local function nameRow(f)
    local label = D.Label(f, L["Name:"])
    label:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.name = D.Edit(f, 230, 20)
    f.name:SetPoint("LEFT", label, "RIGHT", 8, 0)
    f.name:SetScript("OnTextChanged", function()
        setError(nil)
        updateDone()
    end)
    f.name:SetScript("OnEnterPressed", function() OD.Done() end)
end

local function pickers(f)
    f.pickLabel = D.Label(f, L["Automation:"])
    f.pickLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -72)
    f.category = NS.MakeDropdown(f, 110)
    f.trigger = NS.MakeDropdown(f, 170)
    if f.category then
        f.category:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -88)
        f.category.onSelect = function(v) OD.SetCategory(v) end
    end
    if f.trigger then
        f.trigger:SetPoint("TOPLEFT", f, "TOPLEFT", 132, -88)
        f.trigger.onSelect = function(v) OD.SetTrigger(v) end
    end
end

local function radios(f)
    f.buildLabel = D.Label(f, L["Build from:"])
    f.buildLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -120)
    f.radios = {}
    local text = { empty = L["Empty"], current = L["Current items"], stat = L["Best for"] }
    for i, kind in ipairs(BUILDS) do
        local cb = D.Check(f, text[kind])
        cb:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -118 - i * 22)
        cb:SetScript("OnClick", function() OD.SetBuild(kind) end)
        f.radios[kind] = cb
    end
    f.stat = NS.MakeDropdown(f, 150)
    if f.stat then
        f.stat:SetPoint("LEFT", f.radios.stat.label, "RIGHT", 8, 0)
        f.stat.onSelect = function(v) OD.SetStat(v) end
    end
end

local function footer(f)
    f.error = D.ErrorLine(f)
    f.error:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 40)
    f.done = D.Button(f, 80, 22, L["Done"], { primary = true })
    f.done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    f.done:SetScript("OnClick", function() OD.Done() end)
    f.cancel = D.Button(f, 80, 22, L["Cancel"])
    f.cancel:SetPoint("RIGHT", f.done, "LEFT", -6, 0)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
end

local function build()
    if frame then return frame end
    local f = D.New({ name = "OutfitterRebornOutfitDialog", key = "outfit", width = WIDTH, height = HEIGHT,
                      title = L["New Outfit"], onHide = function() st.id = nil end })
    frame = f
    nameRow(f)
    pickers(f)
    radios(f)
    footer(f)
    return f
end

-- The new-mode parts: shown for New, hidden for Rename.
local function showNewParts(on)
    local f = frame
    for _, part in ipairs({ f.pickLabel, f.category, f.trigger, f.buildLabel, f.stat,
                            f.radios.empty, f.radios.current, f.radios.stat }) do
        if part then part:SetShown(on) end
    end
end

-- ── open ──────────────────────────────────────────────────────────────────────────────────────

--- The new-outfit dialog, reset to its defaults.
--- @return boolean opened
function OD.OpenNew()
    if NS.IsStoodDown() then return false end
    build()
    st.mode, st.id, st.autoName = "new", nil, nil
    frame.title:SetText(L["New Outfit"])
    D.SetHeight(frame, HEIGHT)
    showNewParts(true)
    if frame.category then frame.category:SetOptions(categoryOptions()) end
    if frame.stat then frame.stat:SetOptions(statOptions()) end
    OD.SetCategory("GENERAL")
    OD.SetTrigger("")
    OD.SetBuild("current")
    OD.SetStat("STA")
    frame.name:SetText("")
    setError(nil)
    D.Show(frame)
    frame.name:SetFocus()          -- type a name and press Enter (legacy _NameOutfitDialog:Open)
    return true
end

--- The rename dialog for outfit `id`.
--- @return boolean opened
function OD.OpenRename(id)
    local rec = NS.Outfits.Get(id)
    if NS.IsStoodDown() or not rec then return false end
    build()
    st.mode, st.id = "rename", id
    frame.title:SetText(L["Rename Outfit"])
    D.SetHeight(frame, HEIGHT - RENAME_SHORTER)
    showNewParts(false)
    frame.name:SetText(rec.name or "")
    setError(nil)
    D.Show(frame)
    frame.name:SetFocus()
    return true
end

--- Close without creating or renaming anything.
function OD.Close(_)
    if frame and frame:IsShown() then frame:Hide() end
end

function OD.IsOpen() return frame ~= nil and frame:IsShown() == true end

--- The frame, built on first use (the suites read its controls).
function OD.Frame() return build() end
