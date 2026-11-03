local _, NS = ...
-- modules/Dialog_Rebuild.lua — NS.RebuildDialog: the multi-stat rebuild dialog (design §7.6, §5.14).
--
-- "Rebuild for..." on the outfit menu. Rows of a stat dropdown, an operator ("Highest", "At most",
-- "At least": the words, since ≤ and ≥ are outside localization-§7's safe set) and a value, with an
-- add and a remove mark, and a "Complex" check that forces the genetic search. GetConfig answers the
-- §5.14 cfg, `{ { stat, min?, max? }, complex? }`; Done keeps it on the outfit (NS.Outfits.SetStat,
-- so the menu's "Rebuild for <stat>" offers it next time, as the legacy StatConfig did) and runs
-- NS.Optimize.Rebuild. Written fresh: the legacy Update was a broken copy (INV §7.9).
--
-- THE ROWS are drawn from NS.Pool, acquired per render and parked on the next; the draft (`st.rows`)
-- is the truth, the frames only show it.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Get/SetStat, NS.Optimize.Rebuild,
-- NS.ProgressDialog.Install, NS.Stats.Categories.

local R = {}
NS.RebuildDialog = R

local L = NS.L
local D = NS.Dialogs

local WIDTH, HEIGHT = 380, 300
local ROW_H, MAX_ROWS = 26, 6
local OPS = { "highest", "atMost", "atLeast" }

local frame, pool
local st = { rows = {}, complex = false }

local function opLabels()
    return { highest = L["Highest"], atMost = L["At most"], atLeast = L["At least"] }
end

local function statOptions()
    local out = {}
    for _, cat in ipairs(NS.Stats.Categories()) do
        out[#out + 1] = { label = cat.label, title = true }
        for _, stat in ipairs(cat.stats()) do out[#out + 1] = { value = stat.id, label = stat.label } end
    end
    return out
end

local function opOptions()
    local labels, out = opLabels(), {}
    for i, op in ipairs(OPS) do out[i] = { value = op, label = labels[op] } end
    return out
end

-- ── the rows ──────────────────────────────────────────────────────────────────────────────────

local render

local function newRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(WIDTH - 28, ROW_H)
    r.stat = NS.MakeDropdown(r, 140)
    if r.stat then r.stat:SetPoint("LEFT", r, "LEFT", 0, 0) end
    r.op = NS.MakeDropdown(r, 90)
    if r.op then r.op:SetPoint("LEFT", r, "LEFT", 146, 0) end
    r.value = D.Edit(r, 50, 20)
    r.value:SetPoint("LEFT", r, "LEFT", 242, 0)
    r.remove = CreateFrame("Button", nil, r)
    r.remove:SetSize(14, 14)
    r.remove:SetPoint("LEFT", r, "LEFT", 300, 0)
    r.remove.icon = r.remove:CreateTexture(nil, "ARTWORK")
    r.remove.icon:SetAllPoints(r.remove)
    r.remove.icon:SetTexture(NS.Icon("cancel"))
    NS.Skin.Mark(r.remove.icon)
    return r
end

-- Wire one pooled row to draft row `i` (its handlers are rebound on every render).
local function bindRow(r, i)
    local row = st.rows[i]
    if r.stat then
        r.stat:SetOptions(statOptions())
        r.stat:SelectValue(row.stat)
        r.stat.onSelect = function(v) row.stat = v end
    end
    if r.op then
        r.op:SetOptions(opOptions())
        r.op:SelectValue(row.op)
        r.op.onSelect = function(v) row.op = v; render() end
    end
    r.value:SetScript("OnTextChanged", nil)
    r.value:SetText(row.value or "")
    r.value:SetShown(row.op ~= "highest")
    r.value:SetScript("OnTextChanged", function(self) row.value = self:GetText() end)
    r.remove:SetShown(#st.rows > 1)
    r.remove:SetScript("OnClick", function() R.RemoveRow(i) end)
end

render = function()
    if not frame then return end
    NS.Pool.ReleaseAll(pool)
    for i = 1, #st.rows do
        local r = NS.Pool.Acquire(pool, function() return newRow(frame.rowsHost) end)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame.rowsHost, "TOPLEFT", 0, -(i - 1) * ROW_H)
        bindRow(r, i)
    end
    frame.add:SetEnabled(#st.rows < MAX_ROWS)
    frame.complex:SetChecked(st.complex)
end

-- A cfg row as the draft's: the operator read from which bound it carries.
local function draftRow(e)
    if e.min then return { stat = e.stat, op = "atLeast", value = tostring(e.min) } end
    if e.max then return { stat = e.stat, op = "atMost", value = tostring(e.max) } end
    return { stat = e.stat or "STA", op = "highest" }
end

--- Add a row (Highest Stamina), up to six.
function R.AddRow()
    if #st.rows >= MAX_ROWS then return false end
    st.rows[#st.rows + 1] = { stat = "STA", op = "highest" }
    render()
    return true
end

--- Remove row `i`; the last row stays.
function R.RemoveRow(i)
    if #st.rows <= 1 or not st.rows[i] then return false end
    table.remove(st.rows, i)
    render()
    return true
end

--- Set row `i`: its stat, its operator ("highest", "atMost", "atLeast") and its value.
function R.SetRow(i, stat, op, value)
    local row = st.rows[i]
    if not row then return false end
    row.stat, row.op, row.value = stat, op or "highest", value
    render()
    return true
end

--- The "Complex" check: the genetic search even for one row.
function R.SetComplex(on)
    st.complex = on == true
    render()
end

--- The §5.14 cfg the rows describe.
--- @return table
function R.GetConfig()
    local cfg = {}
    for i, row in ipairs(st.rows) do
        local e, v = { stat = row.stat }, tonumber(row.value)
        if row.op == "atLeast" and v then e.min = v end
        if row.op == "atMost" and v then e.max = v end
        cfg[i] = e
    end
    if st.complex then cfg.complex = true end
    return cfg
end

--- Done: keep the cfg on the outfit and rebuild it.
--- @return boolean
function R.Done()
    if not (frame and frame:IsShown() and st.id) or NS.IsStoodDown() then return false end
    local id, cfg = st.id, R.GetConfig()
    NS.Outfits.SetStat(id, cfg)
    NS.ProgressDialog.Install()
    NS.Optimize.Rebuild(id, cfg)
    frame:Hide()
    return true
end

-- ── the frame ─────────────────────────────────────────────────────────────────────────────────

local function build()
    if frame then return frame end
    local f = D.New({ name = "OutfitterRebornRebuildDialog", key = "rebuild", width = WIDTH, height = HEIGHT,
                      title = L["Rebuild"], onHide = function() st.id = nil end })
    frame = f
    pool = NS.Pool.New()
    f.rowsHost = CreateFrame("Frame", nil, f)
    f.rowsHost:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -36)
    f.rowsHost:SetSize(WIDTH - 28, ROW_H * MAX_ROWS)
    f.add = D.Button(f, 90, 20, L["Add a stat"])
    f.add:SetPoint("TOPLEFT", f.rowsHost, "BOTTOMLEFT", 0, -4)
    f.add:SetScript("OnClick", function() R.AddRow() end)
    f.complex = D.Check(f, L["Complex"])
    f.complex:SetPoint("LEFT", f.add, "RIGHT", 12, 0)
    f.complex:SetScript("OnClick", function(self) st.complex = self:GetChecked() == true end)
    f.done = D.Button(f, 80, 22, L["Rebuild"], { primary = true })
    f.done:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    f.done:SetScript("OnClick", function() R.Done() end)
    f.cancel = D.Button(f, 80, 22, L["Cancel"])
    f.cancel:SetPoint("RIGHT", f.done, "LEFT", -6, 0)
    f.cancel:SetScript("OnClick", function() f:Hide() end)
    return f
end

--- Open on outfit `id`, its rows from its own stat cfg (Highest Stamina when it has none).
--- @return boolean opened
function R.Open(id)
    local rec = NS.Outfits.Get(id)
    if NS.IsStoodDown() or not rec then return false end
    build()
    st.id, st.rows, st.complex = id, {}, false
    local cfg = type(rec.stat) == "table" and #rec.stat > 0 and rec.stat or { { stat = "STA" } }
    for i, e in ipairs(cfg) do st.rows[i] = draftRow(e) end
    st.complex = cfg.complex == true
    frame.title:SetText(L["Rebuild %s"]:format(tostring(rec.name or "")))
    render()
    D.Show(frame)
    return true
end

function R.Close(_)
    if frame and frame:IsShown() then frame:Hide() end
end

function R.IsOpen() return frame ~= nil and frame:IsShown() == true end

function R.Frame() return build() end
