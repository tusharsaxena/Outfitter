local _, NS = ...
-- modules/Dialog_Trigger.lua — NS.TriggerDialog: the trigger chooser and its settings (design §7.6, H1,
-- H12, H13; it replaces the legacy script editor, INV §9.8).
--
-- WHAT IT SHOWS. "Automation for <outfit>"; a category and a trigger dropdown (with No trigger) and
-- the trigger's description; the trigger's settings, one editor per visible param from
-- modules/Dialog_TriggerFields.lua, or "There are no settings for this trigger."; and the two flags,
-- "Disable outfit in combat" and "Turn this trigger off". There is no text to type a trigger into:
-- every trigger is native (H1).
--
-- STAGED EDITING. Open builds a DRAFT: each param's stored value, or the DESCRIPTOR's default
-- (NS.TriggerParams.Resolve; never the type's, INV §9.8). Nothing is written until Done, which:
--   1. reads every editor back, and runs NS.Triggers.ValidateParam on each key that changed; a refusal
--      goes on that field's error line and nothing at all is written;
--   2. writes the changed keys, the trigger id when it changed and the flags when they changed in ONE
--      NS.Schema.SetMany(entries, { instanceId = id }): `trigger.<TID>.<key>` and `outfit.trigger.*`
--      rows only, all or nothing, announced as OUTFIT_EDITED (the binder's one rebind route).
-- A trigger's runtime state (`triggerState`, the Fishing restores) is not in the draft, so Done
-- cannot wipe it. Picking another trigger keeps what was typed for the first, should it be picked
-- again. Cancel, the close mark and Escape all hide the frame, and the hide drops the draft (the
-- legacy close mark saved).
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Get, NS.Triggers.Get/List/Categories/
-- ValidateParam, NS.TriggerParams.Resolve, NS.TriggerFields, NS.Schema.SetMany, NS.OutfitMenu.CategoryLabel.

local TD = {}
NS.TriggerDialog = TD

local L = NS.L
local D = NS.Dialogs

local WIDTH, HEIGHT = 420, 440
local BODY_TOP, BODY_BOTTOM = 84, 96

local frame
local draft            -- the open edit, or nil

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function TF() return NS.TriggerFields end

local function visible(p) return not (p.hidden and p.hidden()) end

-- ── the draft ─────────────────────────────────────────────────────────────────────────────────

-- The values a trigger's editors start from, kept twice: what is edited and what Done compares to.
local function startValues(tid)
    if draft.values[tid] then return draft.values[tid] end
    local desc = NS.Triggers.Get(tid)
    local rec = NS.Outfits.Get(draft.id)
    local stored = rec and rec.triggerParams and rec.triggerParams[tid]
    local values = desc and NS.TriggerParams.Resolve(desc, stored) or {}
    draft.values[tid], draft.initial[tid] = values, {}
    for k, v in pairs(values) do draft.initial[tid][k] = v end
    return values
end

-- Read every editor back into the draft.
local function collect()
    local values = draft.values[draft.tid]
    for key, ed in pairs(draft.fields) do values[key] = TF().Get(ed) end
end

-- ── the fields ────────────────────────────────────────────────────────────────────────────────

local function layoutFields(desc, values)
    local y = 0
    for _, p in ipairs(desc.params or {}) do
        if visible(p) then
            local ed = TF().Acquire(p.type, frame.child)
            ed:ClearAllPoints()
            ed:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
            TF().TYPES[p.type].set(ed, values[p.key], p)
            draft.fields[p.key] = ed
            y = y + TF().TYPES[p.type].height
        end
    end
    frame.child:SetHeight(math.max(1, y))
    return y
end

local function showFlags(on)
    for _, cb in ipairs({ frame.combat, frame.off }) do
        cb:SetEnabled(on)
        cb:SetChecked(on and draft[cb.flag] == true)
    end
end

-- Rebuild the body for trigger `tid` ("" is none).
local function showTrigger(tid)
    if draft.fields then collect() end
    TF().ReleaseAll()
    draft.fields, draft.tid = {}, tid
    local desc = NS.Triggers.Get(tid)
    frame.desc:SetText(desc and desc.desc or "")
    if frame.trigger then frame.trigger:SelectValue(tid) end
    local height = desc and layoutFields(desc, startValues(tid)) or 0
    frame.none:SetShown(desc ~= nil and height == 0)
    showFlags(tid ~= "")
end

-- ── the pickers ───────────────────────────────────────────────────────────────────────────────

local function triggerOptions(category)
    local out = { { value = "", label = L["No trigger"] } }
    for _, d in ipairs(NS.Triggers.List(category, NS.Compat.PlayerClass())) do
        out[#out + 1] = { value = d.id, label = d.name, tooltip = d.desc }
    end
    return out
end

--- The trigger dropdown's category.
function TD.SetCategory(category)
    if not draft then return end
    draft.category = category
    if frame.trigger then frame.trigger:SetOptions(triggerOptions(category)) end
    if frame.category then frame.category:SelectValue(category) end
end

--- Pick trigger `tid` ("" is none) in the draft.
function TD.SetTrigger(tid)
    if not draft then return end
    showTrigger(tid or "")
end

-- ── done ──────────────────────────────────────────────────────────────────────────────────────

local function flagEntries(entries)
    if draft.tid == "" then return end
    for _, flag in ipairs({ "disabled", "combatDisabled" }) do
        if draft[flag] ~= draft.start[flag] then
            entries[#entries + 1] = { path = "outfit.trigger." .. flag, value = draft[flag] == true }
        end
    end
end

-- The changed params as entries; false when one is refused (its reason on its field).
local function paramEntries(entries)
    local desc = NS.Triggers.Get(draft.tid)
    if not desc then return true end
    local ok = true
    local values, initial = draft.values[draft.tid], draft.initial[draft.tid]
    for key, ed in pairs(draft.fields) do
        local v = values[key]
        ed.error:SetText("")       -- the last Done's reason goes; a failure below writes this one's
        if not same(v, initial[key]) then
            local pass, why = NS.Triggers.ValidateParam(desc, key, v)
            if pass then
                entries[#entries + 1] = { path = "trigger." .. draft.tid .. "." .. key, value = v }
            else
                ed.error:SetText(tostring(why or ""))
                ok = false
            end
        end
    end
    return ok
end

--- Done: validate, then write the draft in one batch. False, with the reasons shown, when refused.
--- @return boolean
function TD.Done()
    if not draft or NS.IsStoodDown() then return false end
    collect()
    frame.error:SetText("")
    local entries = {}
    if draft.tid ~= draft.start.tid then entries[1] = { path = "outfit.trigger.id", value = draft.tid } end
    local ok = paramEntries(entries)
    flagEntries(entries)
    if not ok then return false end
    if #entries > 0 then
        local written, err = NS.Schema.SetMany(entries, { instanceId = draft.id })
        if not written then
            frame.error:SetText(tostring(err or ""))
            return false
        end
    end
    frame:Hide()
    return true
end

-- ── the frame ─────────────────────────────────────────────────────────────────────────────────

local function pickers(f)
    f.category = NS.MakeDropdown(f, 130)
    f.trigger = NS.MakeDropdown(f, 230)
    if f.category then
        f.category:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
        f.category.onSelect = function(v) TD.SetCategory(v) end
    end
    if f.trigger then
        f.trigger:SetPoint("TOPLEFT", f, "TOPLEFT", 152, -34)
        f.trigger.onSelect = function(v) TD.SetTrigger(v) end
    end
    f.desc = D.Label(f, "", "muted")
    f.desc:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -62)
    f.desc:SetWidth(WIDTH - 28)
end

local function body(f)
    f.body = CreateFrame("ScrollFrame", nil, f)
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -BODY_TOP)
    f.body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, BODY_BOTTOM)
    f.child = CreateFrame("Frame", nil, f.body)
    f.child:SetSize(WIDTH - 44, 1)
    f.body:SetScrollChild(f.child)
    f.body:EnableMouseWheel(true)
    f.body:SetScript("OnMouseWheel", function(self, delta)
        local v = NS.SafeNumber(self:GetVerticalScroll(), 0) - NS.SafeNumber(delta, 0) * 20
        self:SetVerticalScroll(math.max(0, v))
    end)
    f.none = D.Label(f.body, L["There are no settings for this trigger."], "muted")
    f.none:SetPoint("TOPLEFT", f.body, "TOPLEFT", 0, 0)
end

local function flags(f)
    f.combat = D.Check(f, L["Disable outfit in combat"])
    f.combat:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 66)
    f.combat.flag = "combatDisabled"
    f.off = D.Check(f, L["Turn this trigger off"])
    f.off:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 44)
    f.off.flag = "disabled"
    for _, cb in ipairs({ f.combat, f.off }) do
        cb:SetScript("OnClick", function(self) if draft then draft[self.flag] = self:GetChecked() == true end end)
    end
end

local function footer(f)
    f.error = D.ErrorLine(f)
    f.error:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 30)
    f.done = D.Button(f, 80, 22, L["Done"], { primary = true })
    f.done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 8)
    f.done:SetScript("OnClick", function() TD.Done() end)
    f.cancel = D.Button(f, 80, 22, L["Cancel"])
    f.cancel:SetPoint("RIGHT", f.done, "LEFT", -6, 0)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
end

-- Every close path is a hide: the draft and the editors go with it.
local function onHide()
    draft = nil
    TF().ReleaseAll()
end

local function build()
    if frame then return frame end
    local f = D.New({ name = "OutfitterRebornTriggerDialog", key = "trigger", width = WIDTH, height = HEIGHT,
                      title = "", onHide = onHide })
    frame = f
    pickers(f)
    body(f)
    flags(f)
    footer(f)
    return f
end

-- ── open ──────────────────────────────────────────────────────────────────────────────────────

local function categoryOptions()
    local out = {}
    for _, cat in ipairs(NS.Triggers.Categories(NS.Compat.PlayerClass())) do
        out[#out + 1] = { value = cat, label = NS.OutfitMenu.CategoryLabel(cat) }
    end
    return out
end

--- Open the trigger dialog on outfit `id`.
--- @return boolean opened
function TD.Open(id)
    local rec = NS.Outfits.Get(id)
    if NS.IsStoodDown() or not rec then return false end
    build()
    if frame:IsShown() then frame:Hide() end
    local trig = rec.trigger or {}
    local tid = trig.id or ""
    draft = { id = id, values = {}, initial = {}, disabled = trig.disabled == true,
              combatDisabled = trig.combatDisabled == true }
    draft.start = { tid = tid, disabled = draft.disabled, combatDisabled = draft.combatDisabled }
    frame.title:SetText(L["Automation for %s"]:format(tostring(rec.name or "")))
    frame.error:SetText("")
    if frame.category then frame.category:SetOptions(categoryOptions()) end
    local desc = NS.Triggers.Get(tid)
    TD.SetCategory(desc and desc.category or "GENERAL")
    showTrigger(tid)
    D.Show(frame)
    return true
end

--- Close and discard the draft.
function TD.Close(_)
    if frame and frame:IsShown() then frame:Hide() end
end

function TD.IsOpen() return frame ~= nil and frame:IsShown() == true end

--- The frame, built on first use.
function TD.Frame() return build() end
